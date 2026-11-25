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
