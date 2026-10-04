#!/bin/bash

# Build Release Apps Script
# This script compiles the swift package and packages it into two standalone Mac app bundles.

echo "Building Swift Package..."
swift build -c release

echo "Creating App Bundles..."
# Create Main App Bundle
mkdir -p OneLyrics.app/Contents/MacOS
cp .build/release/OneLyrics OneLyrics.app/Contents/MacOS/OneLyrics
echo "Created OneLyrics.app"

# Create Exporter App Bundle
mkdir -p OneLyricsExporter.app/Contents/MacOS
cp .build/release/OneLyrics OneLyricsExporter.app/Contents/MacOS/OneLyricsExporter
echo "Created OneLyricsExporter.app"

echo "Done! You can now move these apps to your Applications folder."
