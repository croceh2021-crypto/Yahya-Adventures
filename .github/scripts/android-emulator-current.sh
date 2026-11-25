#!/usr/bin/env bash
set -Eeuo pipefail

RESULTS_DIR="test-results"
mkdir -p "$RESULTS_DIR"

collect_diagnostics() {
  adb logcat -d -v time > "$RESULTS_DIR/logcat.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$RESULTS_DIR/activities.txt" 2>&1 || true
  adb shell pidof com.yahya.adventures > "$RESULTS_DIR/game-pid.txt" 2>&1 || true
}

echo "Waiting for Android emulator"
adb wait-for-device

boot_state=""
for attempt in $(seq 1 90); do
  boot_state="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$boot_state" == "1" ]]; then
    break
  fi
  sleep 2
done
[[ "$boot_state" == "1" ]] || { echo "Android emulator did not finish booting"; exit 1; }

echo "Preparing emulator display"
adb shell wm size 854x480
adb logcat -c

echo "Installing current main-branch APK"
adb install -r build/YahyaAdventures.apk

echo "Launching Yahya Adventures"
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.yahya.adventures > "$RESULTS_DIR/launch.txt"
cat "$RESULTS_DIR/launch.txt"

swiftc -O .github/scripts/recognize-screen.swift -o "$RESULTS_DIR/recognize-screen"

echo "Waiting for the actual game intro (up to 90 seconds)"
intro_found=0
for attempt in $(seq 1 18); do
  sleep 5
  pid="$(adb shell pidof com.yahya.adventures | tr -d '\r' || true)"
  if [[ -z "$pid" ]]; then
    collect_diagnostics
    echo "Game process exited before the intro appeared"
    exit 1
  fi

  adb exec-out screencap -p > "$RESULTS_DIR/intro-screen.png"
  if [[ -s "$RESULTS_DIR/intro-screen.png" ]]; then
    "$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/intro-screen.png" > "$RESULTS_DIR/intro-text.txt" 2>&1 || true
    # OCR may split the two title words across separate lines.
    # Normalize line breaks before matching the complete title.
    tr '\n' ' ' < "$RESULTS_DIR/intro-text.txt" > "$RESULTS_DIR/intro-text-normalized.txt"
    if grep -E -i "YAHYA[[:space:]]+ADVENTURES" "$RESULTS_DIR/intro-text-normalized.txt"; then
      intro_found=1
      break
    fi
  fi
done

if [[ "$intro_found" != "1" ]]; then
  collect_diagnostics
  echo "Intro title did not appear within 90 seconds. OCR from final screen:"
  cat "$RESULTS_DIR/intro-text.txt" || true
  echo "Relevant Godot/Android diagnostics:"
  grep -E -i "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:|FATAL EXCEPTION|Fatal signal|Yahya Adventures|_ready|create_garden|visual" "$RESULTS_DIR/logcat.txt" | tail -n 180 || true
  echo "The final screenshot and complete diagnostics are attached as artifacts."
  exit 1
fi

echo "Intro detected. Tapping Start Adventure"
adb shell input tap 427 290
sleep 12
pid="$(adb shell pidof com.yahya.adventures | tr -d '\r' || true)"
if [[ -z "$pid" ]]; then
  collect_diagnostics
  echo "Game process stopped after Start Adventure tap"
  exit 1
fi

adb exec-out screencap -p > "$RESULTS_DIR/after-start-screen.png"
test -s "$RESULTS_DIR/after-start-screen.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/after-start-screen.png" > "$RESULTS_DIR/after-start-text.txt" 2>&1 || true

collect_diagnostics
if grep -E -i "FATAL EXCEPTION|Fatal signal|SIGSEGV|Process com\\.yahya\\.adventures.*(died|has died)" "$RESULTS_DIR/logcat.txt"; then
  echo "Fatal Android/app error found"
  exit 1
fi
if grep -E -i "SCRIPT ERROR:|Failed to load script .* with error|Parse Error:" "$RESULTS_DIR/logcat.txt"; then
  echo "Godot script error found"
  exit 1
fi

echo "PASS: APK installed, game intro detected, Start tap sent, app remained alive, no fatal/script errors"
