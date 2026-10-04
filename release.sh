#!/bin/bash
set -e

VERSION="2.0.0"
BUILD="15"

function build_and_package() {
    ARCH=$1
    DMG_NAME=$2
    
    echo "Building release binary for $ARCH..."
    swift build -c release --arch $ARCH
    
    echo "Creating App Bundle Structure for $ARCH..."
    APP_DIR="OneLyrics.app"
    EXP_APP_DIR="OneLyricsExporter.app"
    rm -rf "$APP_DIR" "$EXP_APP_DIR"
    
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"
    mkdir -p "$EXP_APP_DIR/Contents/MacOS"
    mkdir -p "$EXP_APP_DIR/Contents/Resources"
    
    echo "Writing Info.plist for OneLyrics..."
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
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

    echo "Writing Info.plist for OneLyricsExporter..."
    cat > "$EXP_APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OneLyricsExporter</string>
    <key>CFBundleIdentifier</key>
    <string>com.onelyrics.exporter</string>
    <key>CFBundleName</key>
    <string>OneLyricsExporter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

    echo "Copying binary..."
    cp .build/out/Products/Release/OneLyrics "$APP_DIR/Contents/MacOS/OneLyrics"
    cp .build/out/Products/Release/OneLyrics "$EXP_APP_DIR/Contents/MacOS/OneLyricsExporter"

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
        cp "$APP_DIR/Contents/Resources/AppIcon.icns" "$EXP_APP_DIR/Contents/Resources/AppIcon.icns"
        rm -R MyIcon.iconset
    fi

    echo "Signing the App Bundles..."
    codesign --force --deep -s - "$APP_DIR"
    codesign --force --deep -s - "$EXP_APP_DIR"

    echo "Creating DMG..."
    DMG_ROOT="DMG_Root_${ARCH}"
    rm -rf "$DMG_ROOT"
    mkdir -p "$DMG_ROOT"
    cp -R "$APP_DIR" "$DMG_ROOT/"
    cp -R "$EXP_APP_DIR" "$DMG_ROOT/"
    ln -s /Applications "$DMG_ROOT/Applications"

    rm -f "${DMG_NAME}"
    hdiutil create -volname "OneLyrics v${VERSION}" -srcfolder "$DMG_ROOT" -ov -format UDZO "${DMG_NAME}"
}

# Build and package both architectures
build_and_package "arm64" "OneLyrics-AppleSilicon.dmg"
build_and_package "x86_64" "OneLyrics-Intel.dmg"

echo "Uploading DMG to GitHub..."
export PATH="/usr/bin:$PATH"

# Create release if it doesn't exist
if [ -f "ReleaseNotes/v${VERSION}.md" ]; then
    gh release create v${VERSION} -t "v${VERSION}" -F "ReleaseNotes/v${VERSION}.md" || true
else
    gh release create v${VERSION} -t "v${VERSION}" -n "v${VERSION} Release" || true
fi

# Upload the dmgs
gh release upload v${VERSION} OneLyrics-AppleSilicon.dmg --clobber
gh release upload v${VERSION} OneLyrics-Intel.dmg --clobber

echo "Done!"
