#!/bin/bash
set -e

VERSION="2.0.5"
EXPORTER_VERSION="1.0.5"
BUILD="20"

function generate_appicon() {
    LOGO_PATH="/Users/itech/Downloads/onelyricslogo.png"
    if [ -f "$LOGO_PATH" ] && [ ! -f "AppIcon.icns" ]; then
        echo "Generating AppIcon.icns..."
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
        iconutil -c icns MyIcon.iconset -o "AppIcon.icns"
        rm -R MyIcon.iconset
    fi
}

function build_and_package_main() {
    ARCH=$1
    DMG_NAME=$2
    
    echo "Building release binary for $ARCH..."
    swift build -c release --arch $ARCH
    
    echo "Creating App Bundle Structure for OneLyrics ($ARCH)..."
    APP_DIR="OneLyrics.app"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"
    
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

    echo "Copying binary..."
    cp .build/out/Products/Release/OneLyrics "$APP_DIR/Contents/MacOS/OneLyrics"

    if [ -f "AppIcon.icns" ]; then
        cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    fi

    echo "Signing the App Bundle..."
    codesign --force --deep -s - "$APP_DIR"

    echo "Creating DMG..."
    DMG_ROOT="DMG_Root_Main_${ARCH}"
    rm -rf "$DMG_ROOT"
    mkdir -p "$DMG_ROOT"
    cp -R "$APP_DIR" "$DMG_ROOT/"
    ln -s /Applications "$DMG_ROOT/Applications"

    rm -f "${DMG_NAME}"
    hdiutil create -volname "OneLyrics v${VERSION}" -srcfolder "$DMG_ROOT" -ov -format UDZO "${DMG_NAME}"
}

function build_and_package_exporter() {
    ARCH=$1
    DMG_NAME=$2
    
    echo "Creating App Bundle Structure for OneLyricsExporter ($ARCH)..."
    EXP_APP_DIR="OneLyricsExporter.app"
    rm -rf "$EXP_APP_DIR"
    mkdir -p "$EXP_APP_DIR/Contents/MacOS"
    mkdir -p "$EXP_APP_DIR/Contents/Resources"
    
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
    <string>${EXPORTER_VERSION}</string>
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
    cp .build/out/Products/Release/OneLyrics "$EXP_APP_DIR/Contents/MacOS/OneLyricsExporter"

    if [ -f "AppIcon.icns" ]; then
        cp AppIcon.icns "$EXP_APP_DIR/Contents/Resources/AppIcon.icns"
    fi

    echo "Signing the App Bundle..."
    codesign --force --deep -s - "$EXP_APP_DIR"

    echo "Creating DMG..."
    DMG_ROOT="DMG_Root_Exp_${ARCH}"
    rm -rf "$DMG_ROOT"
    mkdir -p "$DMG_ROOT"
    cp -R "$EXP_APP_DIR" "$DMG_ROOT/"
    ln -s /Applications "$DMG_ROOT/Applications"

    rm -f "${DMG_NAME}"
    hdiutil create -volname "OneLyricsExporter v${EXPORTER_VERSION}" -srcfolder "$DMG_ROOT" -ov -format UDZO "${DMG_NAME}"
}

rm -f AppIcon.icns
generate_appicon

# Build and package both architectures
build_and_package_main "arm64" "OneLyrics-AppleSilicon.dmg"
build_and_package_main "x86_64" "OneLyrics-Intel.dmg"

build_and_package_exporter "arm64" "OneLyricsExporter-AppleSilicon.dmg"
build_and_package_exporter "x86_64" "OneLyricsExporter-Intel.dmg"

echo "Uploading DMGs to GitHub..."
export PATH="/usr/bin:$PATH"

# Create a unified Suite release
if [ -f "ReleaseNotes/v${VERSION}.md" ]; then
    gh release create v${VERSION} -t "OneLyrics Suite v${VERSION}" -F "ReleaseNotes/v${VERSION}.md" || true
else
    gh release create v${VERSION} -t "OneLyrics Suite v${VERSION}" -n "OneLyrics Suite v${VERSION} Release" || true
fi

# Upload all 4 DMGs to the same release
gh release upload v${VERSION} OneLyrics-AppleSilicon.dmg --clobber
gh release upload v${VERSION} OneLyrics-Intel.dmg --clobber
gh release upload v${VERSION} OneLyricsExporter-AppleSilicon.dmg --clobber
gh release upload v${VERSION} OneLyricsExporter-Intel.dmg --clobber

echo "Cleaning up..."
rm -f AppIcon.icns
echo "Done!"
