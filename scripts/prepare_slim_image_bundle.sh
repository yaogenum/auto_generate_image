#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_IMAGES_DIR="${APP_IMAGES_DIR:-$ROOT_DIR/build/Debug-iphonesimulator/CartoonWorld.app/images}"
SOURCE_IMAGES_DIR="${SOURCE_IMAGES_DIR:-$ROOT_DIR/images}"
CACHE_IMAGES_DIR="${CACHE_IMAGES_DIR:-$ROOT_DIR/build/CartoonWorldSlimImages/images}"
MAX_DIMENSION="${CARTOON_SLIM_IMAGE_MAX_DIMENSION:-1200}"

if [[ "${CARTOON_PREPARE_SLIM_IMAGES:-1}" == "0" ]]; then
  echo "Slim image bundle disabled."
  exit 0
fi

if [[ ! -d "$APP_IMAGES_DIR" ]]; then
  echo "App image bundle not found: $APP_IMAGES_DIR"
  exit 0
fi

if [[ ! -d "$SOURCE_IMAGES_DIR/source" ]]; then
  echo "Source images not found: $SOURCE_IMAGES_DIR/source"
  exit 0
fi

mkdir -p "$CACHE_IMAGES_DIR/source"

if [[ -f "$SOURCE_IMAGES_DIR/素材元数据.json" ]]; then
  cp "$SOURCE_IMAGES_DIR/素材元数据.json" "$CACHE_IMAGES_DIR/素材元数据.json"
fi

while IFS= read -r -d '' source_path; do
  file_name="$(basename "$source_path")"
  target_path="$CACHE_IMAGES_DIR/source/$file_name"
  extension="${file_name##*.}"
  extension="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"

  if [[ -f "$target_path" && "$target_path" -nt "$source_path" ]]; then
    continue
  fi

  case "$extension" in
    jpg|jpeg|png|heic|tif|tiff)
      if ! sips -Z "$MAX_DIMENSION" "$source_path" --out "$target_path" >/dev/null 2>&1; then
        cp "$source_path" "$target_path"
      fi
      ;;
    *)
      cp "$source_path" "$target_path"
      ;;
  esac
done < <(find "$SOURCE_IMAGES_DIR/source" -maxdepth 1 -type f -print0)

before_size="$(du -sh "$APP_IMAGES_DIR" 2>/dev/null | awk '{print $1}')"
rm -rf "$APP_IMAGES_DIR"
cp -R "$CACHE_IMAGES_DIR" "$APP_IMAGES_DIR"
after_size="$(du -sh "$APP_IMAGES_DIR" 2>/dev/null | awk '{print $1}')"

echo "Prepared slim app image bundle: ${before_size:-unknown} -> ${after_size:-unknown}"
