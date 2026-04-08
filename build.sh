#!/bin/bash
set -e

APP_DIR="build/Termoss.app"
BINARY="$APP_DIR/Contents/MacOS/MobaXterm_macOS"

echo "Building..."
swift build

echo "Packaging .app bundle..."
cp .build/debug/MobaXterm_macOS "$BINARY"

# Copy SwiftTerm resources if present
RESOURCES_SRC=$(find .build/debug -name "SwiftTerm_SwiftTerm.bundle" -type d 2>/dev/null | head -1)
if [ -n "$RESOURCES_SRC" ]; then
    cp -R "$RESOURCES_SRC" "$APP_DIR/Contents/Resources/"
fi

# Copy app icon
if [ -f "MobaXterm_macOS/Resources/AppIcon.icns" ]; then
    cp "MobaXterm_macOS/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc sign the app so Keychain stops prompting for permission
echo "Signing..."
codesign --force --deep --sign - "$APP_DIR"

echo "Done! Launching Termoss.app..."
pkill -f MobaXterm_macOS 2>/dev/null || true
sleep 0.3
open "$APP_DIR"
