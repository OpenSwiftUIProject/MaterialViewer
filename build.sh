#!/bin/bash
set -euo pipefail

tool_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$tool_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
cli_path="$tool_dir/dist/MaterialRecipeViewer"
app_dir="$tool_dir/dist/Material Recipe Viewer.app"
mkdir -p "$app_dir/Contents/MacOS"
# Remove recipe copies left by earlier builds.
rm -rf "$app_dir/Contents/Resources/Recipes"
cp "$binary_dir/MaterialRecipeViewer" "$cli_path"
cp "$cli_path" "$app_dir/Contents/MacOS/MaterialRecipeViewer"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>MaterialRecipeViewer</string>
    <key>CFBundleIdentifier</key><string>org.OpenSwiftUIProject.MaterialViewer</string>
    <key>CFBundleName</key><string>Material Recipe Viewer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app_dir"
printf '%s\n' "$cli_path" "$app_dir"
