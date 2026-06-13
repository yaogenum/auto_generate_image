#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

xcodebuild \
  -project "$ROOT_DIR/CartoonWorld.xcodeproj" \
  -target CartoonWorld \
  -configuration Debug \
  -sdk iphonesimulator \
  build \
  CODE_SIGNING_ALLOWED=NO
