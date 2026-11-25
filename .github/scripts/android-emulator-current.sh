#!/usr/bin/env bash
set -Eeuo pipefail

RESULTS_DIR="test-results"
mkdir -p "$RESULTS_DIR"

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

sleep 20
pid="$(adb shell pidof com.yahya.adventures | tr -d '\r' || true)"
[[ -n "$pid" ]] || { echo "Game process did not stay alive after launch"; exit 1; }

echo "Capturing intro screen"
adb exec-out screencap -p > "$RESULTS_DIR/intro-screen.png"
test -s "$RESULTS_DIR/intro-screen.png"
swiftc -O .github/scripts/recognize-screen.swift -o "$RESULTS_DIR/recognize-screen"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/intro-screen.png" > "$RESULTS_DIR/intro-text.txt"
cat "$RESULTS_DIR/intro-text.txt"
grep -E -i "YAHYA[[:space:]]+ADVENTURES" "$RESULTS_DIR/intro-text.txt"

echo "Tapping Start Adventure"
adb shell input tap 427 290
sleep 10
pid="$(adb shell pidof com.yahya.adventures | tr -d '\r' || true)"
[[ -n "$pid" ]] || { echo "Game process stopped after Start Adventure tap"; exit 1; }

adb exec-out screencap -p > "$RESULTS_DIR/after-start-screen.png"
test -s "$RESULTS_DIR/after-start-screen.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/after-start-screen.png" > "$RESULTS_DIR/after-start-text.txt" || true

echo "Collecting Android logcat"
adb logcat -d -v time > "$RESULTS_DIR/logcat.txt"
if grep -E -i "FATAL EXCEPTION|Fatal signal|SIGSEGV|Process com\\.yahya\\.adventures.*(died|has died)" "$RESULTS_DIR/logcat.txt"; then
  echo "Fatal Android/app error found"
  exit 1
fi
if grep -E -i "SCRIPT ERROR:|Failed to load script .* with error|Parse Error:" "$RESULTS_DIR/logcat.txt"; then
  echo "Godot script error found"
  exit 1
fi

echo "PASS: APK installed, game launched, intro title detected, Start tap sent, app remained alive, no fatal/script errors"
