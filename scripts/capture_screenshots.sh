#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.codex.CartoonWorld"
APP_PATH="$ROOT_DIR/build/Debug-iphonesimulator/CartoonWorld.app"
OUTPUT_DIR="$ROOT_DIR/artifacts/screenshots"
SHOOT_DELAY_SECONDS="${CARTOON_SCREENSHOT_DELAY_SECONDS:-5.0}"
mkdir -p "$OUTPUT_DIR"

if [[ ! -d "$ROOT_DIR/CartoonWorld.xcodeproj" ]]; then
  echo "Missing project root: $ROOT_DIR"
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App binary not found: $APP_PATH"
  echo "Run ./scripts/build_ios.sh first."
  exit 1
fi

SIM_ID="$(xcrun simctl list devices booted | awk '/(Booted)/ {
  for (i = 1; i <= NF; i++) {
    token = $i
    gsub(/[()]/, "", token)
    if (token ~ /^[A-F0-9-]{36}$/) { print token; exit }
  }
}' | head -n 1)"

if [[ -z "$SIM_ID" ]]; then
  SIM_ID="$(xcrun simctl list devices | awk 'BEGIN {state=0} /Booted/ {state=1} state==1 && /Booted/ {print $NF}' | head -n 1)"
fi

if [[ -z "$SIM_ID" ]]; then
  echo "No booted simulator found. Please run ./scripts/run_ios_sim.sh to prepare a booted simulator."
  exit 1
fi

xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM_ID" "$APP_PATH"

shot() {
  local name="$1"
  shift
  local -a launchArgs=()
  local -a envArgs=()
  for pair in "$@"; do
    launchArgs+=("--${pair}")
    envArgs+=("SIMCTL_CHILD_${pair}")
  done

  printf '\n[Shot] %s\n' "$name"
    (
      env "${envArgs[@]}" xcrun simctl launch --terminate-running-process "$SIM_ID" "$BUNDLE_ID" "${launchArgs[@]}" >/tmp/cartoonworld-launch.log 2>&1
  )
  sleep "$SHOOT_DELAY_SECONDS"
  if [[ "$name" == "world_nagoya_explore" ]]; then
    sleep "${CARTOON_NAGOYA_SCREENSHOT_EXTRA_DELAY_SECONDS:-7}"
  fi
  xcrun simctl io "$SIM_ID" screenshot "$OUTPUT_DIR/$name.png"
}

# Family flow
shot "family_topology_compact" \
  "CARTOON_INITIAL_TAB=family" \
  "CARTOON_INITIAL_FAMILY_LAYOUT=拓扑" \
  "CARTOON_INITIAL_FAMILY_EXPANDED=0"

shot "family_topology_expanded" \
  "CARTOON_INITIAL_TAB=family" \
  "CARTOON_INITIAL_FAMILY_LAYOUT=拓扑" \
  "CARTOON_INITIAL_FAMILY_EXPANDED=1"

shot "family_list" \
  "CARTOON_INITIAL_TAB=family" \
  "CARTOON_INITIAL_FAMILY_LAYOUT=列表" \
  "CARTOON_INITIAL_FAMILY_EXPANDED=0"

shot "family_human_offline_status" \
  "CARTOON_INITIAL_TAB=family" \
  "CARTOON_INITIAL_FAMILY_LAYOUT=拓扑" \
  "CARTOON_INITIAL_FAMILY_EXPANDED=0" \
  "CARTOON_INITIAL_FAMILY_CONTACT_ENDPOINT=offline"

shot "family_call_tray_expanded" \
  "CARTOON_INITIAL_TAB=family" \
  "CARTOON_INITIAL_FAMILY_LAYOUT=列表" \
  "CARTOON_INITIAL_FAMILY_EXPANDED=0" \
  "CARTOON_INITIAL_FAMILY_CONTACT_ENDPOINT=human" \
  "CARTOON_INITIAL_FAMILY_CALL_TRAY_EXPANDED=1"

# World flow - 上海 真实3D 起步（关系网络）
shot "world_shanghai_real_compact" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=上海" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=地点" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=0" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=the-bund"

# 世界页 - 探索展开：便于对比与前一张的面板差异
shot "world_shanghai_cartoon_compact" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=上海" \
  "CARTOON_INITIAL_WORLD_MODE=cartoon" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=地点" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=the-bund"

# 世界页 - 东京真实3D
shot "world_tokyo_real_explore" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=东京" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=地点" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=tokyo-tower"

# 世界页 - 东京地标点击后的列表（模拟）
shot "world_tokyo_moments" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=东京" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=Moments" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=tokyo-tower"

# 世界页 - 名古屋真实3D
shot "world_nagoya_explore" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=名古屋" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=地点" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=nagoya-castle"

# 世界页 - 大阪 Moments + 地标互动映射
shot "world_osaka_moments" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=大阪" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=Moments" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=osaka-castle"

# 世界页 - 香港关系网络（关系配置）
shot "world_hk_relations" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=香港" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=家人互动" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=victoria-harbour"

# 世界页 - 地标关系映射（切到Moments并回选到热门点）
shot "world_hk_moments_focus" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=香港" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=Moments" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=victoria-harbour"

# 地图动作演示：关闭UI，检验最小化可用性
shot "world_ui_hidden" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=香港" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_UI_HIDDEN=1" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=victoria-harbour"

shot "world_ui_restored" \
  "CARTOON_INITIAL_TAB=world" \
  "CARTOON_INITIAL_WORLD_CITY=香港" \
  "CARTOON_INITIAL_WORLD_MODE=real3D" \
  "CARTOON_INITIAL_WORLD_PANEL_EXPANDED=1" \
  "CARTOON_INITIAL_WORLD_PANEL_SECTION=地点" \
  "CARTOON_INITIAL_WORLD_UI_HIDDEN=0" \
  "CARTOON_INITIAL_WORLD_SELECTED_PLACE=victoria-harbour"

# 上传与身份
shot "upload" \
  "CARTOON_INITIAL_TAB=upload"

shot "profile" \
  "CARTOON_INITIAL_TAB=profile"

echo "Screenshots saved to: $OUTPUT_DIR"
