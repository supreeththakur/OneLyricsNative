# OneLyrics 🎵

**OneLyrics** is a high-performance, fully native macOS application suite for creating professional lyrical videos. Built entirely with SwiftUI and AppKit, it delivers a buttery smooth editing experience, real-time typography scaling, and flawless export capabilities using `AVAssetWriter`.

The suite is now divided into two powerful standalone applications:
- **OneLyrics**: The primary lyric video creation and editing engine.
- **OneLyrics Exporter**: A dedicated, premium queue manager and render engine for offloading background video exports, keeping your main editing workflow completely lag-free.

## 🚀 Features

* **Standalone Exporter Suite:** Manage all your active, queued, and completed renders in a dedicated, beautifully crafted macOS interface with folder-like hierarchies, auto-resume capabilities, job prioritization, and fail-safe recovery.
* **MP3 Auto-Conversion:** Automatically converts unsupported audio files (like MP3) to M4A for seamless timeline scrubbing and guaranteed `AVAssetWriter` export compatibility.
* **Native Video Exporting:** Export your lyric videos natively using `AVAssetWriter` with zero deadlocks. Features perfectly interleaved audio/video channels and high-performance, hardware-accelerated rendering.
* **Dynamic Timeline UI:** A professional NLE-style timeline that scrolls buttery smooth in perfect sync with the playhead during playback, powered by direct AppKit (`NSScrollView`) integration for zero UI lag.
* **WYSIWYG Typography Scaling:** Lyrics text dynamically scales perfectly relative to a 16:9 1080p canvas using accurate proportions, ensuring what you see in the editor is exactly what gets exported.
* **Customizable Shadow/Glow:** High-end typography features including adjustable fonts, sizing, glow intensity, and real-time previewing.
* **SRT Parsing:** Easily import, edit, and sync LRC/SRT files.

## 📦 Installation

We provide separate standalone binaries for both Apple Silicon and Intel Macs.

1. Head over to the [Releases](https://github.com/supreeththakur/OneLyricsNative/releases) page.
2. Download the `.dmg` file that matches your Mac's architecture (`AppleSilicon` or `Intel`):
   - `OneLyrics-[Arch].dmg` for the main editing app.
   - `OneLyricsExporter-[Arch].dmg` for the standalone render engine.
3. Open the DMG and drag the app into your `Applications` folder.
4. Launch the app and start creating!

## 🛠️ Development

### Requirements
- macOS 13.0 Ventura or later
- Xcode 15 or later
- Swift 5.10 or later

### Build Instructions
To build and run the app locally during development:
```bash
swift build -c release
swift run
```

### Packaging a Release
To package the apps into DMGs and automatically upload them to GitHub Releases, use our custom release script:
```bash
./release.sh
```
*Note: This script requires `gh` (GitHub CLI), `sips`, and `iconutil`. It will automatically build both architectures for the Main App and the Exporter, sign the binaries, bundle the `AppIcon`, create four separate DMG files, and push them to their respective GitHub Release tags.*
