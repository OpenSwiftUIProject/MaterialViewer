#!/bin/bash
set -euo pipefail

tool_dir="$(cd "$(dirname "$0")" && pwd)"

exec xcodebuild \
    -project "$tool_dir/MaterialViewer.xcodeproj" \
    -scheme MaterialViewer \
    -configuration "${CONFIGURATION:-Release}" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$tool_dir/DerivedData" \
    build "$@"
