#!/bin/bash
set -euo pipefail
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHOT_DIR="$ROOT_DIR/artifacts/screenshots"
REPORT="${SHOT_DIR}/screenshot-qa-assertion.txt"
EXPECTED=(
  world_shanghai_real_compact.png
  world_shanghai_cartoon_compact.png
  world_tokyo_real_explore.png
  world_tokyo_moments.png
  world_nagoya_explore.png
  world_osaka_moments.png
  world_hk_relations.png
  world_hk_moments_focus.png
  world_ui_hidden.png
  world_ui_restored.png
  family_topology_compact.png
  family_topology_expanded.png
  family_list.png
  family_human_offline_status.png
  family_call_tray_expanded.png
  upload.png
  profile.png
)

MIN_SIZE_BYTES=60000
seen_file="$(mktemp)"
trap 'rm -f "$seen_file"' EXIT

{
  echo "# 截图QA断言 $(date '+%Y-%m-%d %H:%M:%S')"
  echo "目录: $SHOT_DIR"
  echo

  pass=0
  fail=0

  for name in "${EXPECTED[@]}"; do
    path="$SHOT_DIR/$name"
    if [[ ! -f "$path" ]]; then
      echo "FAIL missing: $name"
      ((fail+=1))
      continue
    fi

    size=$(stat -f%z "$path")
    width=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}' | tr -cd '0-9')
    height=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}' | tr -cd '0-9')
    hash=$(md5 -q "$path")

    if (( size < MIN_SIZE_BYTES )); then
      echo "FAIL size-too-small: $name size=${size}"
      ((fail+=1))
      continue
    fi

    if [[ -z "$width" || -z "$height" ]]; then
      echo "FAIL invalid-dim: $name"
      ((fail+=1))
      continue
    fi

    if grep -Fxq "$hash $name" "$seen_file"; then
      first="$(awk -v h="$hash" '$1==h {print $2; exit}' "$seen_file")"
      echo "FAIL duplicate-hash: $name 与 ${first:-?}"
      ((fail+=1))
      continue
    fi

    echo "$hash $name" >> "$seen_file"

    echo "PASS $name (${width}x${height}) size=${size} hash=${hash:0:12}..."
    ((pass+=1))
  done

  echo
  echo "PASS_COUNT=$pass"
  echo "FAIL_COUNT=$fail"

  if (( fail > 0 )); then
    echo "RESULT=BLOCKED"
    exit 1
  fi

  echo "RESULT=OK"
  } | tee "$REPORT"
