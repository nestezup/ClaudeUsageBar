#!/bin/bash
set -e

APP_NAME="ClaudeUsageBar"
BUILD_DIR=".build/debug"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"

echo "Stopping old instance..."
pkill -x ClaudeUsageBar 2>/dev/null || true
sleep 0.5

echo "Building..."
swift build

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ClaudeUsageBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.nest.claude-usage-bar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeUsageBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.nest.claude-usage-bar</string>
    </array>
</dict>
</plist>
EOF

echo "App bundle created at: $APP_BUNDLE"
echo "Launching..."
open "$APP_BUNDLE"
