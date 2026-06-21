#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/Debug-iphonesimulator/CartoonWorld.app"
BUNDLE_ID="com.codex.CartoonWorld"
DEVICE_TYPE="${DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-16e}"
SIM_NAME="${SIM_NAME:-CartoonWorld-iPhone}"
SIMCTL_TIMEOUT="${SIMCTL_TIMEOUT:-25}"
AUTO_DEMO="${CARTOON_AUTO_DEMO:-0}"

run_simctl() {
  local label="$1"
  shift
  "$@" &
  local pid=$!
  local elapsed=0
  while kill -0 "$pid" >/dev/null 2>&1; do
    if (( elapsed >= SIMCTL_TIMEOUT )); then
      echo "Timed out while ${label}; killing process ${pid}." >&2
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid"
}

if ! xcrun simctl list runtimes available | grep -q "com.apple.CoreSimulator.SimRuntime.iOS"; then
  echo "No available iOS Simulator runtime was found."
  echo "Install one in Xcode > Settings > Components, then rerun this script."
  exit 1
fi

RUNTIME_ID="$(xcrun simctl list runtimes available | awk '/com.apple.CoreSimulator.SimRuntime.iOS/ {print $NF; exit}')"

"$ROOT_DIR/scripts/build_ios.sh"

SIM_ID="$(xcrun simctl list devices booted | awk -v name="$SIM_NAME" '
  $0 ~ name && /Booted/ {
    for (i=1; i<=NF; i++) {
      token=$i
      gsub(/[()]/, "", token)
      if (token ~ /^[A-F0-9-]{36}$/) { print token; exit }
    }
  }')"
if [[ -z "${SIM_ID:-}" ]]; then
  SIM_ID="$(xcrun simctl list devices booted | awk '/Booted/ {
    for (i=1; i<=NF; i++) {
      token=$i
      gsub(/[()]/, "", token)
      if (token ~ /^[A-F0-9-]{36}$/) { print token; exit }
    }
  }')"
fi
if [[ -z "${SIM_ID:-}" ]]; then
  SIM_ID="$(xcrun simctl list devices "$RUNTIME_ID" | awk -v name="$SIM_NAME" '$0 ~ name {
    for (i=1; i<=NF; i++) {
      token=$i
      gsub(/[()]/, "", token)
      if (token ~ /^[A-F0-9-]{36}$/) { print token; exit }
    }
  }')"
fi
if [[ -z "${SIM_ID:-}" ]]; then
  SIM_ID="$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$RUNTIME_ID")"
fi

xcrun simctl boot "$SIM_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_ID" -b >/dev/null 2>&1 || true
open -a Simulator
run_simctl "terminating existing app" xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
run_simctl "uninstalling existing app" xcrun simctl uninstall "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
run_simctl "installing app" xcrun simctl install "$SIM_ID" "$APP_PATH"

AUTO_DEMO_NORMALIZED="$(printf '%s' "$AUTO_DEMO" | tr '[:upper:]' '[:lower:]')"
if [[ "$AUTO_DEMO_NORMALIZED" == "1" || "$AUTO_DEMO_NORMALIZED" == "true" || "$AUTO_DEMO_NORMALIZED" == "yes" || "$AUTO_DEMO_NORMALIZED" == "enabled" ]]; then
  run_simctl "launching app with auto demo" \
    env SIMCTL_CHILD_CARTOON_AUTO_DEMO=1 \
    xcrun simctl launch --terminate-running-process "$SIM_ID" "$BUNDLE_ID"
else
  run_simctl "launching app" xcrun simctl launch --terminate-running-process "$SIM_ID" "$BUNDLE_ID"
fi
