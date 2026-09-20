#!/bin/bash
set -e

echo "Building release binary..."
swift build -c release

echo "Creating App Bundle Structure..."
APP_DIR="OneLyrics.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "Writing Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OneLyrics</string>
    <key>CFBundleIdentifier</key>
    <string>com.onelyrics.native</string>
    <key>CFBundleName</key>
    <string>OneLyrics</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "Copying binary..."
cp .build/release/OneLyrics "$APP_DIR/Contents/MacOS/"

echo "Generating AppIcon..."
LOGO_PATH="/Users/itech/Downloads/onelyricslogo.png"
if [ -f "$LOGO_PATH" ]; then
    mkdir -p MyIcon.iconset
    sips -z 16 16     "$LOGO_PATH" --out MyIcon.iconset/icon_16x16.png
    sips -z 32 32     "$LOGO_PATH" --out MyIcon.iconset/icon_16x16@2x.png
    sips -z 32 32     "$LOGO_PATH" --out MyIcon.iconset/icon_32x32.png
    sips -z 64 64     "$LOGO_PATH" --out MyIcon.iconset/icon_32x32@2x.png
    sips -z 128 128   "$LOGO_PATH" --out MyIcon.iconset/icon_128x128.png
    sips -z 256 256   "$LOGO_PATH" --out MyIcon.iconset/icon_128x128@2x.png
    sips -z 256 256   "$LOGO_PATH" --out MyIcon.iconset/icon_256x256.png
    sips -z 512 512   "$LOGO_PATH" --out MyIcon.iconset/icon_256x256@2x.png
    sips -z 512 512   "$LOGO_PATH" --out MyIcon.iconset/icon_512x512.png
    sips -z 1024 1024 "$LOGO_PATH" --out MyIcon.iconset/icon_512x512@2x.png
    iconutil -c icns MyIcon.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -R MyIcon.iconset
fi

echo "Signing the App Bundle..."
codesign --force --deep -s - "$APP_DIR"

echo "Creating DMG..."
DMG_ROOT="DMG_Root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create -volname "OneLyrics" -srcfolder "$DMG_ROOT" -ov -format UDZO OneLyrics.dmg

echo "Uploading DMG to GitHub..."
export PATH="/usr/bin:$PATH"

# Create release if it doesn't exist
gh release create v1.1 -t "v1.1" -n "v1.1 Release" || true

# Upload the dmg
gh release upload v1.1 OneLyrics.dmg --clobber

echo "Done!"
