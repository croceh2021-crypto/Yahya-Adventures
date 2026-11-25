#!/usr/bin/env bash
set -Eeuo pipefail

RESULTS_DIR="test-results"
mkdir -p "$RESULTS_DIR"

run_with_timeout() {
  local seconds="$1"
  shift
  perl -e '$t = shift; alarm $t; exec @ARGV' "$seconds" "$@"
}

capture_diagnostics() {
  local exit_code=$?
  mkdir -p "$RESULTS_DIR"
  run_with_timeout 30 adb logcat -d -v time > "$RESULTS_DIR/logcat-on-exit.txt" 2>&1 || true
  run_with_timeout 20 adb exec-out screencap -p > "$RESULTS_DIR/screen-on-exit.png" 2>/dev/null || true
  printf 'Smoke test exit code: %s\n' "$exit_code" > "$RESULTS_DIR/exit-status.txt"
  return 0
}
trap capture_diagnostics EXIT

adb_retry() {
  local attempt
  for attempt in 1 2 3; do
    if adb "$@"; then
      return 0
    fi
    echo "ADB command failed (attempt $attempt/3): $*" >&2
    adb reconnect offline || true
    adb start-server || true
    sleep 3
  done
  echo "ADB command failed after 3 attempts: $*" >&2
  return 1
}

echo "Waiting for Android device"
run_with_timeout 120 adb wait-for-device
boot_state=""
for attempt in $(seq 1 60); do
  boot_state="$(adb_retry shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  [[ "$boot_state" == "1" ]] && break
  sleep 2
done
[[ "$boot_state" == "1" ]] || { echo "Android did not finish booting"; exit 1; }

echo "Waiting for Android package manager service"
package_ready=""
for attempt in $(seq 1 45); do
  package_status="$(run_with_timeout 10 adb shell service check package 2>&1 || true)"
  if echo "$package_status" | grep -q "Service package: found"; then
    if run_with_timeout 20 adb shell cmd package list packages --user 0 >/dev/null 2>&1; then
      package_ready="1"
      break
    fi
  fi
  echo "Package manager is not responsive yet (attempt $attempt/45)"
  sleep 2
done
[[ "$package_ready" == "1" ]] || { echo "Android package manager did not become responsive"; exit 1; }

echo "Applying lightweight test display settings"
adb_retry shell wm size 854x480
adb_retry logcat -c

echo "Installing APK without streamed install"
adb_retry install --no-streaming -r build/YahyaAdventures.apk

echo "Launching game directly through Activity Manager"
run_with_timeout 45 adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.yahya.adventures > "$RESULTS_DIR/launch.txt" 2>&1 || {
  cat "$RESULTS_DIR/launch.txt"
  echo "Activity Manager could not launch the game"
  exit 1
}
cat "$RESULTS_DIR/launch.txt"

echo "Waiting for the game process (maximum 60 seconds)"
game_pid=""
for attempt in $(seq 1 30); do
  game_pid="$(adb_retry shell pidof com.yahya.adventures 2>/dev/null | tr -d '\r' || true)"
  [[ -n "$game_pid" ]] && break
  sleep 2
done
[[ -n "$game_pid" ]] || { echo "Game process did not start"; exit 1; }

echo "Preparing Apple Vision OCR to verify the actual game menu"
swiftc -O .github/scripts/recognize-screen.swift -o "$RESULTS_DIR/recognize-screen"

echo "Waiting up to 90 seconds for the main menu title to appear"
menu_found=""
for attempt in $(seq 1 45); do
  adb_retry shell pidof com.yahya.adventures
  adb_retry exec-out screencap -p > "$RESULTS_DIR/game-start.png"
  test -s "$RESULTS_DIR/game-start.png"
  "$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/game-start.png" > "$RESULTS_DIR/screen-text.txt" 2> "$RESULTS_DIR/ocr-error.txt" || true

  if grep -E -i "YAHYA[[:space:]]+ADVENTURES" "$RESULTS_DIR/screen-text.txt"; then
    menu_found="1"
    echo "Verified the YAHYA ADVENTURES main menu title on screen"
    break
  fi

  echo "Main menu title not visible yet (attempt $attempt/45)"
  sleep 2
done

if [[ "$menu_found" != "1" ]]; then
  echo "The game process is running, but the main menu title was not detected within 90 seconds"
  echo "Last OCR output:"
  cat "$RESULTS_DIR/screen-text.txt" || true
  exit 1
fi

echo "TEST 1: Start adventure from the main menu"
# The verified 854x480 menu places the primary start button at screen center, y=290.
adb_retry shell input tap 427 290
sleep 8
adb_retry shell pidof com.yahya.adventures
adb_retry exec-out screencap -p > "$RESULTS_DIR/gameplay-start.png"
test -s "$RESULTS_DIR/gameplay-start.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/gameplay-start.png" > "$RESULTS_DIR/gameplay-text.txt" 2> "$RESULTS_DIR/gameplay-ocr-error.txt" || true

if grep -E -i "YAHYA[[:space:]]+ADVENTURES" "$RESULTS_DIR/gameplay-text.txt"; then
  echo "The intro menu is still visible after pressing Start Adventure"
  exit 1
fi
if ! grep -E "العملات|المرحلة|اجمع" "$RESULTS_DIR/gameplay-text.txt"; then
  echo "Gameplay HUD text was not detected after starting the adventure"
  cat "$RESULTS_DIR/gameplay-text.txt" || true
  exit 1
fi
echo "PASS: Start button leaves the intro menu and displays gameplay HUD"

echo "TEST 2: Movement control"
# Hold the right D-pad button briefly, then release.
adb_retry shell input swipe 780 337 780 337 1200
sleep 2
adb_retry exec-out screencap -p > "$RESULTS_DIR/after-movement.png"
test -s "$RESULTS_DIR/after-movement.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/after-movement.png" > "$RESULTS_DIR/after-movement-text.txt" 2> "$RESULTS_DIR/movement-ocr-error.txt" || true
if ! grep -E "العملات|المرحلة|اجمع" "$RESULTS_DIR/after-movement-text.txt"; then
  echo "Gameplay HUD disappeared after movement input"
  exit 1
fi
echo "PASS: Movement input sent and gameplay HUD remained visible"

echo "TEST 3: Jump control"
adb_retry shell input tap 55 360
sleep 2
adb_retry exec-out screencap -p > "$RESULTS_DIR/after-jump.png"
test -s "$RESULTS_DIR/after-jump.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/after-jump.png" > "$RESULTS_DIR/after-jump-text.txt" 2> "$RESULTS_DIR/jump-ocr-error.txt" || true
if ! grep -E "العملات|المرحلة|اجمع" "$RESULTS_DIR/after-jump-text.txt"; then
  echo "Gameplay HUD disappeared after jump input"
  exit 1
fi
echo "PASS: Jump input sent and gameplay HUD remained visible"

echo "TEST 4: Pause menu"
adb_retry shell input tap 810 40
sleep 2
adb_retry exec-out screencap -p > "$RESULTS_DIR/pause-menu.png"
test -s "$RESULTS_DIR/pause-menu.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/pause-menu.png" > "$RESULTS_DIR/pause-text.txt" 2> "$RESULTS_DIR/pause-ocr-error.txt" || true
if ! grep -E "اللعبة متوقفة" "$RESULTS_DIR/pause-text.txt"; then
  echo "Pause menu title was not detected"
  cat "$RESULTS_DIR/pause-text.txt" || true
  exit 1
fi
echo "PASS: Pause menu appeared"

echo "TEST 5: Resume from pause menu"
adb_retry shell input tap 427 193
sleep 3
adb_retry exec-out screencap -p > "$RESULTS_DIR/resumed-game.png"
test -s "$RESULTS_DIR/resumed-game.png"
"$RESULTS_DIR/recognize-screen" "$RESULTS_DIR/resumed-game.png" > "$RESULTS_DIR/resumed-text.txt" 2> "$RESULTS_DIR/resumed-ocr-error.txt" || true
if grep -E "اللعبة متوقفة" "$RESULTS_DIR/resumed-text.txt"; then
  echo "Pause overlay is still visible after pressing Resume"
  exit 1
fi
if ! grep -E "العملات|المرحلة|اجمع" "$RESULTS_DIR/resumed-text.txt"; then
  echo "Gameplay HUD was not restored after resume"
  cat "$RESULTS_DIR/resumed-text.txt" || true
  exit 1
fi
echo "PASS: Resume restored gameplay HUD"

echo "Capturing final screen after interaction tests"
adb_retry exec-out screencap -p > "$RESULTS_DIR/game-after-input.png"
test -s "$RESULTS_DIR/game-after-input.png"

echo "Collecting Android logs"
adb_retry logcat -d -v time > "$RESULTS_DIR/logcat.txt"
if grep -E -i "FATAL EXCEPTION|Fatal signal|SIGSEGV|Process com\\.yahya\\.adventures.*(died|has died)" "$RESULTS_DIR/logcat.txt"; then
  echo "A fatal Android/app error was found in logcat"
  exit 1
fi

if grep -E -i "SCRIPT ERROR:|Failed to load script .* with error|Parse Error:" "$RESULTS_DIR/logcat.txt"; then
  echo "A Godot script error was found; the game did not load cleanly"
  exit 1
fi

echo "Game process remained running after launch and touch input with no Android or Godot script errors"
