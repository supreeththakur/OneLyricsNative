<div align="center">

# 🎵 OneLyrics Native

### The Ultra-Fast, 100% Native macOS Lyric Video Creator & Studio

[![Swift](https://img.shields.io/badge/Swift-5.10-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
[![Framework](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Engine](https://img.shields.io/badge/Video%20Engine-AVFoundation-34C759?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/av-foundation/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

<br/>

**OneLyrics Native** is a pro-grade, hardware-accelerated macOS desktop studio designed specifically for music artists, video editors, and lyric video creators. Built from scratch with pure Swift, SwiftUI, and AVFoundation — zero Electron bloat, instant startup, and buttery-smooth 60/120Hz ProMotion timeline scrubbing.

</div>

---

## ✨ Features at a Glance

### 🚀 100% Pure Native Performance
- **Zero Webview Overhead:** Native AppKit & SwiftUI architecture for minimal CPU/RAM footprint and instant response.
- **Buttery-Smooth UI:** Modern dark glassmorphic studio interface tailored specifically for macOS Sonoma.

### ⏱️ Pro Timeline & Real-Time Sync
- **Hardware-Accelerated Scrubbing:** Decoupled playhead scrubbing for latency-free dragging with real-time frame previews.
- **Global Studio Shortcuts:** Instant `Spacebar` play/pause control that works globally across the app without focus conflicts.
- **Zoomable Multi-Track Timeline:** Inspect phrases down to the millisecond with responsive zoom controls.
- **Nudge & Global Shift:** Shift all lyrics forward/backward with precise nudges (`-500ms`, `-100ms`, `+100ms`, `+500ms`) for perfect beat alignment.

### 📝 Smart Lyric Importer & Parser
- **Format Support:** Built-in high-performance parser for `.srt`, `.lrc`, and plain `.txt` files.
- **Auto-Timing Generation:** Automatically falls back to intelligent cadence distribution for un-timed raw lyrics.
- **Live Preview:** Instant subtitle block previewing synced to your audio playhead.

### 🎨 Visual Studio & Inspector
- **Preset Styles:** Toggle between aesthetic templates:
  - 🌟 **Clean Music Channel** (Clean modern sans-serif aesthetic)
  - 🎬 **Cinematic** (Dramatic serif typography with soft letter-spacing)
  - 🔮 **Neon** (Vibrant glow & atmospheric illumination)
- **Live Typography Controls:** Real-time font size scaling (24px – 120px) and reactive glow intensity adjustments.
- **Dynamic Backgrounds:** Supports high-res static backdrops (`.png`, `.jpg`, `.webp`) and full-motion synchronized looping video backgrounds (`.mp4`, `.mov`).

### 🎬 High-Throughput Export Engine
- **Hardware-Accelerated Pipeline:** Offscreen pixel buffer generation rendered via `AVAssetWriter` and `CoreGraphics`.
- **Formats:**
  - **MP4 (H.264)** — Highly compatible, optimized for YouTube, Instagram, and web sharing.
  - **MOV (Apple ProRes)** — Pristine broadcast quality for professional video workflows.
- **Resolutions & Aspect Ratios:**
  - 🖥️ **1080p Full HD** (1920 × 1080)
  - 💎 **4K Ultra HD** (3840 × 2160)
  - 📱 **Vertical 9:16** (1080 × 1920) for Instagram Reels, YouTube Shorts, and TikTok.
- **Bitrate Profiles:** Standard, High, and Lossless presets with real-time render percentage progress.

---

## 📸 Workflow & Interface

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [● ● ●] OneLyrics Native — Studio                                             │
├───────────────┬───────────────────────────────────────────────┬───────────────┤
│ ASSETS        │                 PREVIEW VIEW                  │ INSPECTOR     │
│               │                                               │               │
│ • Audio Track │        ┌─────────────────────────────┐        │ • Template    │
│   (MP3/WAV)   │        │                             │        │   [ Clean ▼ ] │
│               │        │     "Wake up to reality"    │        │               │
│ • Background  │        │                             │        │ • Typography  │
│   (MP4/PNG)   │        └─────────────────────────────┘        │   Size: 52px  │
│               │                                               │   Glow: 12px  │
│ • Lyrics      │       ▶  [ 00:01:24 / 00:03:40 ]  🔊         │               │
│   (SRT/LRC)   │                                               │ [ Export Video]│
├───────────────┴───────────────────────────────────────────────┴───────────────┤
│ TIMELINE                                                         [ - ] 🔍 [ + ]│
│ 00:00        00:30        01:00        01:30        02:00        02:30        │
│ [━━━━━━━] [━━━━━━━━━━━] [━━━━━━━━]   │ [━━━━━━━━━━━━━━━━━] [━━━━━━━━━]        │
│                                      ▲ Playhead                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack & Architecture

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Language** | Swift 5.10 | Modern concurrency, performance, and type-safety |
| **UI Framework** | SwiftUI & AppKit | Declarative UI combined with macOS-native window management |
| **Audio/Video Playback** | AVFoundation (`AVPlayer`) | Low-latency audio & video playback synchronization |
| **Export Pipeline** | `AVAssetWriter`, `CVPixelBuffer` | Direct hardware encoding with zero third-party dependencies |
| **Graphics Engine** | CoreGraphics & AppKit Font Engine | Sub-pixel lyric typography rendering with soft glows |
| **File I/O** | `UniformTypeIdentifiers`, `NSOpenPanel` | Native sandboxed macOS file pickers and path resolution |

---

## 📂 Project Structure

```
OneLyricsNative/
├── Package.swift               # Swift Package Manager configuration (macOS v14+)
├── Sources/
│   └── OneLyricsNative/
│       ├── OneLyricsNative.swift   # App entry point & global event monitors (Spacebar)
│       ├── Models/
│       │   └── ProjectState.swift  # Data models for lyric blocks, typography, & project state
│       ├── ViewModels/
│       │   └── ProjectStore.swift  # Central observable state, AVPlayer management & sync
│       ├── Views/
│       │   ├── ContentView.swift      # Three-pane layout shell with toolbar
│       │   ├── PlayerView.swift       # Live video/image viewport & rendered subtitles
│       │   ├── TimelineView.swift     # Interactive playhead, lyric blocks & zoom engine
│       │   ├── Sidebars.swift         # Asset importer panel & inspector controls
│       │   └── ExportModalView.swift  # Export dialog with resolution, format & progress
│       └── Utils/
│           ├── SRTParser.swift        # SubRip (.srt) and Lyric (.lrc) parser
│           └── VideoExporter.swift    # AVAssetWriter render loop & CoreGraphics compositor
└── README.md
```

---

## ⚡ Quick Start

### Prerequisites
- **macOS 14.0 (Sonoma)** or later
- **Xcode 15.0+** or the **Swift 5.10+** command line tools

### 1. Clone the Repository
```bash
git clone https://github.com/supreeththakur/OneLyricsNative.git
cd OneLyricsNative
```

### 2. Run Directly via Terminal
```bash
swift run
```

### 3. Open in Xcode (Optional)
Double-click `Package.swift` or run:
```bash
xed .
```
Select the `OneLyricsNative` executable scheme and hit **⌘R** to build and run.

### 4. Build an Optimized Release Binary
```bash
swift build -c release
# The compiled binary will be located at:
# .build/release/OneLyricsNative
```

---

## ⌨️ Studio Shortcuts

| Key | Action |
| :--- | :--- |
| <kbd>Space</kbd> | Toggle Play / Pause anywhere in the app |
| <kbd>Click + Drag</kbd> | Scrub timeline playhead smoothly to any timestamp |
| <kbd>Zoom Slider</kbd> | Expand/contract timeline resolution |

---

## 🤝 Contributing

Contributions, feature ideas, and pull requests are warmly welcomed!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<div align="center">
  <sub>Crafted with ❤️ for music creators everywhere using Swift & SwiftUI.</sub>
</div>
