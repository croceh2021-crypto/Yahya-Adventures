#!/usr/bin/env bash
set -Eeuo pipefail

RESULTS_DIR="test-results"
mkdir -p "$RESULTS_DIR"

capture_diagnostics() {
  local exit_code=$?
  mkdir -p "$RESULTS_DIR"
  timeout 30s adb logcat -d -v time > "$RESULTS_DIR/logcat-on-exit.txt" 2>&1 || true
  timeout 20s adb exec-out screencap -p > "$RESULTS_DIR/screen-on-exit.png" 2>/dev/null || true
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
timeout 120s adb wait-for-device
boot_state=""
for attempt in $(seq 1 60); do
  boot_state="$(adb_retry shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  [[ "$boot_state" == "1" ]] && break
  sleep 2
done
[[ "$boot_state" == "1" ]] || { echo "Android did not finish booting"; exit 1; }

echo "Applying lightweight test display settings"
adb_retry shell wm size 854x480
adb_retry logcat -c

echo "Installing APK"
adb_retry install -r build/YahyaAdventures.apk

echo "Launching game"
adb_retry shell monkey -p com.yahya.adventures 1

echo "Waiting for the game process (maximum 60 seconds)"
game_pid=""
for attempt in $(seq 1 30); do
  game_pid="$(adb_retry shell pidof com.yahya.adventures 2>/dev/null | tr -d '\r' || true)"
  [[ -n "$game_pid" ]] && break
  sleep 2
done
[[ -n "$game_pid" ]] || { echo "Game process did not start"; exit 1; }

echo "Waiting for initial rendering"
sleep 8
adb_retry shell pidof com.yahya.adventures
adb_retry exec-out screencap -p > "$RESULTS_DIR/game-start.png"
test -s "$RESULTS_DIR/game-start.png"

echo "Sending basic touch input"
adb_retry shell input tap 80 400
sleep 1
adb_retry shell input tap 780 400
sleep 1
adb_retry shell input tap 427 240
sleep 2

echo "Capturing screen after touch input"
adb_retry exec-out screencap -p > "$RESULTS_DIR/game-after-input.png"
test -s "$RESULTS_DIR/game-after-input.png"

echo "Collecting Android logs"
adb_retry logcat -d -v time > "$RESULTS_DIR/logcat.txt"
if grep -E -i "FATAL EXCEPTION|Fatal signal|SIGSEGV|Process com\\.yahya\\.adventures.*(died|has died)" "$RESULTS_DIR/logcat.txt"; then
  echo "A fatal Android/app error was found in logcat"
  exit 1
fi

echo "Game process remained running after launch and touch input"
