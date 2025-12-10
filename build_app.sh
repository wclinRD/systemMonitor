#!/bin/bash
set -e

# Build
swift build -c release

# Create App Bundle
APP_NAME="SystemMonitor"
APP_DIR="$APP_NAME.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy Executable
cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# Copy Info.plist
cp "Info.plist" "$APP_DIR/Contents/"

# Copy Icon
cp "system.icns" "$APP_DIR/Contents/Resources/"

# Code Sign (Ad-hoc) to allow running
codesign --force --deep --sign - "$APP_DIR"

# Copy to Release folder
mkdir -p "release"
rm -rf "release/$APP_DIR"
cp -R "$APP_DIR" "release/"

echo "Build successful: $APP_DIR"
echo "Copied to: release/$APP_DIR"
