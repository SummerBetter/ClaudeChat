#!/bin/bash
set -e

cd "$(dirname "$0")/macapp"

echo "==> Building..."
swift build

echo "==> Killing old ClaudeChat..."
killall ClaudeChat 2>/dev/null || true
sleep 1
pgrep -q ClaudeChat && killall -9 ClaudeChat 2>/dev/null || true

echo "==> Updating app bundle..."
rm -rf /tmp/ClaudeChat.app
mkdir -p /tmp/ClaudeChat.app/Contents/MacOS
cp .build/debug/ClaudeChat /tmp/ClaudeChat.app/Contents/MacOS/ClaudeChat
cat > /tmp/ClaudeChat.app/Contents/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeChat</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.ClaudeChat</string>
    <key>CFBundleName</key>
    <string>ClaudeChat</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Launching..."
open /tmp/ClaudeChat.app

echo "Done."