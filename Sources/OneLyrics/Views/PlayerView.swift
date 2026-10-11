import SwiftUI
import AVKit
import Combine

struct PlayerView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var editingLyricId: UUID? = nil
    @State private var editingText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Letterbox background
            Color.black
            
            // 16:9 Canvas - fixed aspect ratio, never changes size with content
            GeometryReader { geo in
                ZStack {
                if store.state.type == .lyrics {
                    if let bg = store.state.backgroundURL {
                        Group {
                            if bg.pathExtension.lowercased() == "mp4" || bg.pathExtension.lowercased() == "mov" {
                                if let bgPlayer = store.bgPlayer {
                                    Color.clear
                                        .overlay(
                                        AVPlayerViewRepresentable(player: bgPlayer)
                                            .disabled(true)
                                        )
                                }
                            } else if let nsImage = NSImage(contentsOf: bg) {
                                Color.clear
                                    .overlay(
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .scaledToFill()
                                    )
                            }
                        }
                        .scaleEffect(store.state.mediaConfig.cropScale)
                        .offset(
                            x: store.state.mediaConfig.cropOffsetX * (geo.size.width / 1920.0),
                            y: store.state.mediaConfig.cropOffsetY * (geo.size.height / 1080.0)
                        )
                        .brightness(store.state.mediaConfig.brightness)
                        .contrast(store.state.mediaConfig.contrast)
                        .saturation(store.state.mediaConfig.saturation)
                        .clipped()
                    } else {
                        Color(white: 0.1)
                    }
                } else {
                    Color.black
                }
                
                if store.state.type == .visualizer {
                    VisualizerOverlay(geo: geo)
                } else {
                    // Lyrics Overlay
                    let w = geo.size.width
                    let scaledFontSize = store.state.typography.fontSize * (w / 1920.0)
                    let scaledGlow = store.state.typography.glow * (w / 1920.0)
                    
                    VStack {
                        if store.state.typography.alignment == .bottom || store.state.typography.alignment == .bottomLeading {
                            Spacer()
                        } else if store.state.typography.alignment == .center {
                            Spacer()
                        }
                        
                        if let currentLyric = store.state.lyrics.first(where: { store.currentTimeMs >= $0.startMs && store.currentTimeMs <= $0.endMs }) {
                            let text = currentLyric.displayText
                            let start = currentLyric.startMs
                            let end = currentLyric.endMs
                            let t = store.currentTimeMs
                            
                            // Math Engine for SwiftUI WYSIWYG
                            let duration = 300.0 // ms
                            let progressIn = max(0, min(1, (t - start) / duration))
                            let progressOut = max(0, min(1, (end - t) / duration))
                            
                            let anim = store.state.typography.animationStyle
                            
                            let opacity: Double = {
                                if anim == .none { return 1.0 }
                                return min(progressIn, progressOut)
                            }()
                            
                            let scale: Double = {
                                if anim == .pop {
                                    let p = progressIn
                                    return p < 1 ? (0.8 + (p * 0.2)) : 1.0
                                } else if anim == .scaleDown {
                                    let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                    return 1.05 - (totalProgress * 0.05)
                                } else if anim == .scaleUp {
                                    let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                    return 0.95 + (totalProgress * 0.05)
                                }
                                return 1.0
                            }()
                            
                            let blurRadius: Double = {
                                if anim == .blurFade {
                                    return (1.0 - min(progressIn, progressOut)) * 5.0
                                }
                                return 0
                            }()
                            
                            let yOffset: Double = {
                                if anim == .slideUp {
                                    return (1.0 - progressIn) * 50.0 - (1.0 - progressOut) * 50.0
                                } else if anim == .float {
                                    let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                    return 15.0 - (totalProgress * 30.0) // Slow continuous float up
                                } else if anim == .driftUp {
                                    let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                    return 5.0 - (totalProgress * 10.0) // Very subtle drift
                                }
                                return 0
                            }()
                            
                            let xOffset: Double = {
                                if anim == .gentleSlide {
                                    let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                    return -10.0 + (totalProgress * 20.0)
                                }
                                return 0
                            }()
                            
                            let displayText: String = {
                                if anim == .typewriter {
                                    let totalDuration = end - start
                                    let revealDuration = min(totalDuration * 0.5, 1500)
                                    let progress = max(0, min(1, (t - start) / revealDuration))
                                    let charCount = Int(progress * Double(text.count))
                                    return String(text.prefix(charCount))
                                }
                                return text
                            }()
                            
                            let isLeading = store.state.typography.alignment == .bottomLeading
                            
                            let textColor = NSColor(Color(hex: store.state.typography.color))
                            let strokeColor = NSColor(Color(hex: store.state.typography.strokeColor))
                            
                            let glowColorObj = Color(hex: store.state.typography.glowColor ?? "#000000")
                            
                            if editingLyricId == currentLyric.id {
                                TextField("Lyric Text", text: $editingText, onCommit: {
                                    if currentLyric.isTransliteratedActive {
                                        store.updateTransliteratedText(id: currentLyric.id, newText: editingText)
                                    } else {
                                        store.updateLyricText(id: currentLyric.id, newText: editingText)
                                    }
                                    editingLyricId = nil
                                })
                                .focused($isTextFieldFocused)
                                .onChange(of: isTextFieldFocused) { isFocused in
                                    if !isFocused && editingLyricId == currentLyric.id {
                                        if currentLyric.isTransliteratedActive {
                                            store.updateTransliteratedText(id: currentLyric.id, newText: editingText)
                                        } else {
                                            store.updateLyricText(id: currentLyric.id, newText: editingText)
                                        }
                                        editingLyricId = nil
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(Font.custom(store.state.typography.fontFamily, size: scaledFontSize))
                                .foregroundColor(Color(nsColor: textColor))
                                .multilineTextAlignment(isLeading ? .leading : .center)
                                .shadow(color: glowColorObj.opacity(0.8), radius: scaledGlow)
                                .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .center)
                                .padding(.horizontal, store.state.typography.edgePadding * (w/1920.0))
                                .padding(.bottom, store.state.typography.alignment == .bottom ? 40 * (w/1920) : 0)
                                .padding(.top, store.state.typography.alignment == .top ? 40 * (w/1920) : 0)
                                .onAppear {
                                    isTextFieldFocused = true
                                }
                            } else {
                                NativeStrokeText(
                                    text: displayText,
                                    fontName: store.state.typography.fontFamily,
                                    fontSize: scaledFontSize,
                                    textColor: textColor,
                                    strokeColor: strokeColor,
                                    strokeWidth: store.state.typography.hasStroke ? CGFloat(store.state.typography.strokeWidth) : 0,
                                    isLeading: isLeading
                                )
                                .shadow(color: glowColorObj.opacity(0.8), radius: scaledGlow)
                                .opacity(opacity)
                                .scaleEffect(scale)
                                .offset(x: xOffset, y: yOffset)
                                .blur(radius: blurRadius)
                                .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .center)
                                .padding(.horizontal, store.state.typography.edgePadding * (w/1920.0))
                                .padding(.bottom, store.state.typography.alignment == .bottom ? 40 * (w/1920) : 0)
                                .padding(.top, store.state.typography.alignment == .top ? 40 * (w/1920) : 0)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    editingLyricId = currentLyric.id
                                    editingText = currentLyric.isTransliteratedActive ? (currentLyric.transliteratedText ?? currentLyric.text) : currentLyric.text
                                    if store.isPlaying {
                                        store.togglePlayPause()
                                    }
                                }
                            }
                        }
                        
                        if store.state.typography.alignment == .top {
                            Spacer()
                        } else if store.state.typography.alignment == .center {
                            Spacer()
                        }
                    }
                }
            } // End ZStack
            } // End GeometryReader
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
            .padding(16)
            
            // Playback Controls Overlay (bottom)
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    // Play/Pause Button - BIG clickable area
                    Button(action: { store.togglePlayPause() }) {
                        Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Text(formatTimecode(ms: store.currentTimeMs))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("/")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatTimecode(ms: store.effectiveDuration))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 80)
                    , alignment: .bottom
                )
            }
        }
        // Click anywhere on the player to toggle play/pause
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            store.togglePlayPause()
        }
        .onChange(of: store.state.mediaConfig.volume) { _ in
            store.player?.volume = store.state.mediaConfig.volume
        }
    }
    
    func formatTimecode(ms: Double) -> String {
        let totalSeconds = Int(ms / 1000)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

extension Color {
    init(hex: String) {
        var cleanHexCode = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHexCode = cleanHexCode.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleanHexCode).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct CoreTextLabel: NSViewRepresentable {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let textColor: NSColor
    let strokeColor: NSColor
    let strokeWidth: CGFloat
    let isLeading: Bool
    
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: "")
        field.drawsBackground = false
        field.isBordered = false
        field.isEditable = false
        field.isSelectable = false
        field.backgroundColor = .clear
        return field
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = isLeading ? .left : .center
        
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        if strokeWidth > 0 {
            attrs[.strokeColor] = strokeColor
            attrs[.strokeWidth] = strokeWidth // Positive draws ONLY the stroke (hollow)
        }
        
        nsView.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
    }
}

struct NativeStrokeText: View {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let textColor: NSColor
    let strokeColor: NSColor
    let strokeWidth: CGFloat
    let isLeading: Bool
    
    var body: some View {
        ZStack {
            if strokeWidth > 0 {
                // Background layer: Draw the stroke with DOUBLE width because CoreGraphics centers strokes on the path edge
                CoreTextLabel(
                    text: text,
                    fontName: fontName,
                    fontSize: fontSize,
                    textColor: textColor,
                    strokeColor: strokeColor,
                    strokeWidth: strokeWidth * 2.0,
                    isLeading: isLeading
                )
            }
            // Foreground layer: Draw the fill
            CoreTextLabel(
                text: text,
                fontName: fontName,
                fontSize: fontSize,
                textColor: textColor,
                strokeColor: .clear,
                strokeWidth: 0,
                isLeading: isLeading
            )
        }
    }
}

struct AVPlayerViewRepresentable: NSViewRepresentable {
    var player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct VisualizerOverlay: View {
    @EnvironmentObject var store: ProjectStore
    let geo: GeometryProxy
    
    // Timer for syncing with playback
    let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    @State private var currentAmplitudes: [CGFloat] = Array(repeating: 0.02, count: 64)
    @State private var phase: Double = 0.0
    
    var body: some View {
        let w = geo.size.width
        let h = geo.size.height
        let config = store.state.visualizerConfig
        
        let c1 = Color(hex: config.color1)
        let c2 = Color(hex: config.color2)
        let bgC1 = Color(hex: store.extractedColor1)
        let bgC2 = Color(hex: store.extractedColor2)
        let glow = config.glowIntensity
        
        let globalBassAmp = currentAmplitudes[0...3].reduce(0.0, +) / 4.0
        let coverBass = CGFloat(min(1.0, max(0.0, globalBassAmp * 2.8)))
        let glowFactor = CGFloat(glow)
        
        ZStack {
            // Liquid Moving Background (uses Extracted Colors & Blurred Image)
            ZStack {
                Color.black
                
                // The actual background image heavily blurred
                Group {
                    if let firstThumb = store.thumbnails.first?.image {
                        Image(nsImage: firstThumb)
                            .resizable()
                            .scaledToFill()
                    } else if let bgUrl = store.state.backgroundURL, let nsImage = NSImage(contentsOf: bgUrl), bgUrl.pathExtension.lowercased() != "mp4" {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: w, height: h)
                .clipped()
                .blur(radius: w * 0.08, opaque: true)
                .opacity(0.4)
                
                // Ambient Reactive Particles
                AmbientParticles(
                    phase: phase,
                    bassAmp: globalBassAmp,
                    color1: bgC1,
                    color2: bgC2
                )
                .frame(width: w, height: h)
                
                Circle()
                    .fill(bgC1.opacity(0.6))
                    .frame(width: w * 0.8)
                    .offset(x: cos(phase * 0.2) * w * 0.3, y: sin(phase * 0.15) * h * 0.3)
                    .blur(radius: w * 0.15)
                
                Circle()
                    .fill(bgC2.opacity(0.5))
                    .frame(width: w * 0.9)
                    .offset(x: -cos(phase * 0.18) * w * 0.2, y: -sin(phase * 0.22) * h * 0.3)
                    .blur(radius: w * 0.15)
                    
                Circle()
                    .fill(bgC1.opacity(0.3))
                    .frame(width: w * 0.6)
                    .offset(x: sin(phase * 0.25) * w * 0.4, y: cos(phase * 0.2) * h * 0.4)
                    .blur(radius: w * 0.1)
                
                // Beat-reactive radiant spotlight illuminating the background behind the cover image
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                c1.opacity(Double(0.25 + coverBass * 0.55 * glowFactor)),
                                c2.opacity(Double(0.15 + coverBass * 0.45 * glowFactor)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: w * (0.28 + coverBass * 0.14)
                        )
                    )
                    .frame(width: w * (0.55 + coverBass * 0.25), height: w * (0.55 + coverBass * 0.25))
                    .position(x: w * 0.22, y: h * 0.45)
                    .blur(radius: w * 0.08)
            }
            .clipped()
            
            HStack(spacing: 40) {
                // Left Side: Artwork & Title
                VStack(alignment: .center, spacing: 20) {
                    // Song Picture (Artwork with Beat-Reactive Glowing Background / Chamak)
                    ZStack {
                        // 1. Broad Ambient Radial Glow (Chamak) behind cover image
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        c1.opacity(Double(0.45 + coverBass * 0.55 * glowFactor)),
                                        c2.opacity(Double(0.3 + coverBass * 0.5 * glowFactor)),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: (w * 0.22) * (0.8 + coverBass * 0.45)
                                )
                            )
                            .frame(width: w * (0.24 + coverBass * 0.08), height: w * (0.24 + coverBass * 0.08))
                            .blur(radius: 24 + coverBass * 32 * glowFactor)
                        
                        // 2. High-energy inner bloom halo
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        c1.opacity(Double(0.5 + coverBass * 0.5 * glowFactor)),
                                        c2.opacity(Double(0.35 + coverBass * 0.5 * glowFactor))
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * (0.225 + coverBass * 0.025), height: w * (0.225 + coverBass * 0.025))
                            .blur(radius: 10 + coverBass * 16 * glowFactor)
                        
                        // 3. Cover Artwork Image Container
                        Group {
                            if let coverUrl = store.state.coverImageURL, let nsImage = NSImage(contentsOf: coverUrl) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                            } else if let defaultArt = store.defaultArtwork {
                                Image(nsImage: defaultArt)
                                    .resizable()
                                    .scaledToFill()
                            } else if let firstThumb = store.thumbnails.first?.image {
                                Image(nsImage: firstThumb)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(Image(systemName: "music.note").font(.system(size: 60)).foregroundColor(.white.opacity(0.5)))
                            }
                        }
                        .frame(width: w * 0.22, height: w * 0.22)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        // Dynamic Beat-Reactive Glowing Border
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(Double(0.4 + coverBass * 0.6)),
                                            c1.opacity(Double(0.35 + coverBass * 0.65)),
                                            c2.opacity(Double(0.15 + coverBass * 0.55)),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5 + coverBass * 2.5
                                )
                        )
                        // Multi-layered dynamic audio-reactive shadow glow
                        .shadow(color: c1.opacity(Double(0.4 + coverBass * 0.6 * glowFactor)), radius: 25 + coverBass * 40 * glowFactor, x: 0, y: 10)
                        .shadow(color: c2.opacity(Double(0.3 + coverBass * 0.55 * glowFactor)), radius: 10 + coverBass * 22 * glowFactor, x: 0, y: 0)
                        .shadow(color: Color.white.opacity(Double(coverBass * 0.35 * glowFactor)), radius: 8 + coverBass * 14 * glowFactor, x: 0, y: 0)
                        // Dynamic beat bounce scale
                        .scaleEffect(1.0 + (coverBass * 0.04))
                    }
                    
                    if config.textOverlay.showTitle {
                        Text(config.textOverlay.title.isEmpty ? "Song Title" : config.textOverlay.title)
                            .font(.custom(store.state.typography.fontFamily, size: w * 0.04))
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                    }
                    
                    if config.textOverlay.showArtist {
                        Text(config.textOverlay.artist.isEmpty ? "Artist Name" : config.textOverlay.artist)
                            .font(.custom(store.state.typography.fontFamily, size: w * 0.022))
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(width: w * 0.35)
                .padding(.leading, w * 0.05)
                
                // Right Side: Waveform / Visualizer
                VStack {
                    Spacer()
                    
                    // Premium Visualizer Designs
                    Group {
                        if config.type == .spectrumBars {
                            // Mirrored Glassmorphism Bars
                            HStack(alignment: .center, spacing: w * 0.004) {
                                ForEach(0..<40, id: \.self) { i in
                                    let amp = max(0.02, currentAmplitudes[i])
                                    let barHeight = amp * h * 0.5
                                    
                                    RoundedRectangle(cornerRadius: w * 0.002, style: .continuous)
                                        .fill(LinearGradient(colors: [c1, c2], startPoint: .bottom, endPoint: .top))
                                        .frame(width: w * 0.007, height: barHeight)
                                        .shadow(color: c1.opacity(glow * 0.5), radius: glow * 10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: w * 0.002, style: .continuous)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                        )
                                }
                            }
                            .frame(height: h * 0.6)
                        } else if config.type == .waveform {
                            // Smooth Siri-style Glowing Waveform
                            ZStack {
                                // The glowing fill
                                Path { path in
                                    let width = w * 0.45
                                    let step = width / 39.0
                                    let midY = h * 0.25
                                    
                                    path.move(to: CGPoint(x: 0, y: midY))
                                    for i in 1..<40 {
                                        let prevX = CGFloat(i - 1) * step
                                        let currX = CGFloat(i) * step
                                        let prevY = midY - (max(0.01, currentAmplitudes[i-1]) * h * 0.25)
                                        let currY = midY - (max(0.01, currentAmplitudes[i]) * h * 0.25)
                                        let midPoint = CGPoint(x: (prevX + currX) / 2, y: (prevY + currY) / 2)
                                        
                                        if i == 1 {
                                            path.addLine(to: midPoint)
                                        } else {
                                            path.addQuadCurve(to: midPoint, control: CGPoint(x: prevX, y: prevY))
                                        }
                                    }
                                    path.addLine(to: CGPoint(x: width, y: midY - (max(0.01, currentAmplitudes[39]) * h * 0.25)))
                                    
                                    // Mirror bottom half
                                    for i in (1..<40).reversed() {
                                        let prevX = CGFloat(i) * step
                                        let currX = CGFloat(i - 1) * step
                                        let prevY = midY + (max(0.01, currentAmplitudes[i]) * h * 0.25)
                                        let currY = midY + (max(0.01, currentAmplitudes[i-1]) * h * 0.25)
                                        let midPoint = CGPoint(x: (prevX + currX) / 2, y: (prevY + currY) / 2)
                                        
                                        if i == 39 {
                                            path.addLine(to: midPoint)
                                        } else {
                                            path.addQuadCurve(to: midPoint, control: CGPoint(x: prevX, y: prevY))
                                        }
                                    }
                                    path.addLine(to: CGPoint(x: 0, y: midY + (max(0.01, currentAmplitudes[0]) * h * 0.25)))
                                    path.closeSubpath()
                                }
                                .fill(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing))
                                .blur(radius: glow * 10)
                                .opacity(0.8)
                                
                                // Center bright stroke line
                                Path { path in
                                    let width = w * 0.45
                                    let step = width / 39.0
                                    let midY = h * 0.25
                                    
                                    path.move(to: CGPoint(x: 0, y: midY - (max(0.01, currentAmplitudes[0]) * h * 0.25)))
                                    for i in 1..<40 {
                                        let prevX = CGFloat(i - 1) * step
                                        let currX = CGFloat(i) * step
                                        let prevY = midY - (max(0.01, currentAmplitudes[i-1]) * h * 0.25)
                                        let currY = midY - (max(0.01, currentAmplitudes[i]) * h * 0.25)
                                        let midPoint = CGPoint(x: (prevX + currX) / 2, y: (prevY + currY) / 2)
                                        
                                        if i == 1 {
                                            path.addLine(to: midPoint)
                                        } else {
                                            path.addQuadCurve(to: midPoint, control: CGPoint(x: prevX, y: prevY))
                                        }
                                    }
                                    path.addLine(to: CGPoint(x: width, y: midY - (max(0.01, currentAmplitudes[39]) * h * 0.25)))
                                }
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .shadow(color: c1.opacity(0.8), radius: glow * 5)
                            }
                            .frame(width: w * 0.45, height: h * 0.5)
                        } else if config.type == .circular {
                            // Ultra Premium Circular (Trap Nation Style)
                            ZStack {
                                let bassAmp = currentAmplitudes[0...3].reduce(0, +) / 4.0
                                let centerScale = 1.0 + (bassAmp * 0.15)
                                
                                // Inner Artwork Circle (Pulsing & Rotating)
                                ZStack {
                                    if let firstThumb = store.thumbnails.first?.image {
                                        Image(nsImage: firstThumb)
                                            .resizable()
                                            .scaledToFill()
                                    } else if let bgUrl = store.state.backgroundURL, let nsImage = NSImage(contentsOf: bgUrl), bgUrl.pathExtension.lowercased() != "mp4" {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: w * 0.15, height: w * 0.15)
                                .clipShape(Circle())
                                .rotationEffect(Angle(degrees: phase * 15)) // Slow rotation
                                .scaleEffect(centerScale)
                                .shadow(color: c1.opacity(glow * 0.8), radius: glow * 30)
                                .overlay(
                                    Circle()
                                        .stroke(LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                                        .scaleEffect(centerScale)
                                )
                                
                                // Symmetrical Radial Bars
                                let numBars = 90
                                ForEach(0..<numBars, id: \.self) { i in
                                    // Symmetrical mapping: 0 to 45 maps to 0..39 spectrum bins
                                    let isRightHalf = i >= (numBars / 2)
                                    let indexInHalf = isRightHalf ? (numBars - 1 - i) : i
                                    let mappedIdx = Int((Double(indexInHalf) / Double(numBars / 2)) * 39.0)
                                    
                                    let amp = max(0.01, currentAmplitudes[mappedIdx])
                                    let barHeight = amp * h * 0.25
                                    // Start from bottom (90 degrees) and spread outwards symmetrically
                                    let angle = Angle(degrees: Double(i) / Double(numBars) * 360.0 + 90.0) 
                                    
                                    // The main bar
                                    RoundedRectangle(cornerRadius: w * 0.002, style: .continuous)
                                        .fill(LinearGradient(colors: [c1, c2.opacity(0.5)], startPoint: .bottom, endPoint: .top))
                                        .frame(width: w * 0.0035, height: barHeight)
                                        .offset(y: -w * 0.085 - barHeight / 2) // Push out from center artwork
                                        .rotationEffect(angle)
                                        .scaleEffect(centerScale)
                                        .shadow(color: c1.opacity(glow * 0.5), radius: glow * 10)
                                        
                                    // A glowing dot at the end of the bar for extra flair
                                    Circle()
                                        .fill(c2)
                                        .frame(width: w * 0.004)
                                        .offset(y: -w * 0.085 - barHeight - (w * 0.005))
                                        .rotationEffect(angle)
                                        .scaleEffect(centerScale)
                                        .shadow(color: c2, radius: glow * 5)
                                        .opacity(amp > 0.05 ? 1.0 : 0.0) // Only show dots for loud frequencies
                                }
                            }
                            .frame(width: w * 0.45, height: h * 0.6)
                        } else {
                            // Frequency Reactive - High Energy Geometric Rings
                            let bass = currentAmplitudes[0...3].reduce(0, +) / 4.0
                            let mid = currentAmplitudes[10...15].reduce(0, +) / 6.0
                            let treble = currentAmplitudes[30...35].reduce(0, +) / 6.0
                            
                            ZStack {
                                // Bass Ring (Solid)
                                Circle()
                                    .fill(c1)
                                    .frame(width: w * 0.1 + (bass * w * 0.3))
                                    .blur(radius: glow * 20)
                                    .opacity(0.8)
                                    
                                // Mid Ring (Dashed/Stroked)
                                Circle()
                                    .stroke(c2, style: StrokeStyle(lineWidth: w * 0.005 + (mid * w * 0.02), dash: [10, 15]))
                                    .frame(width: w * 0.15 + (mid * w * 0.4))
                                    .rotationEffect(Angle(degrees: phase * 100))
                                    .shadow(color: c2.opacity(glow * 0.8), radius: glow * 10)
                                    
                                // Treble Points
                                ForEach(0..<8, id: \.self) { i in
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: w * 0.01 + (treble * w * 0.02))
                                        .offset(y: -w * 0.1 - (treble * w * 0.15))
                                        .rotationEffect(Angle(degrees: (Double(i) / 8.0 * 360.0) + (phase * -50)))
                                        .shadow(color: .white, radius: glow * 10)
                                }
                            }
                            .frame(width: w * 0.45, height: h * 0.5)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, w * 0.05)
            }
        }
        .scaleEffect(1.0 + (globalBassAmp * 0.04)) // Cinematic Camera Pump on Beat!
        .animation(.spring(response: 0.1, dampingFraction: 0.6, blendDuration: 0.0), value: globalBassAmp)
        .onReceive(timer) { _ in
            if store.isPlaying && !store.spectrumData.isEmpty {
                phase += 0.01
                // Determine which frame to pick based on currentTimeMs
                let timeSecs = store.currentTimeMs / 1000.0
                let frameIndex = Int(timeSecs * store.spectrumFps)
                
                if frameIndex >= 0 && frameIndex < store.spectrumData.count {
                    let frame = store.spectrumData[frameIndex]
                    // Smoothly animate towards target
                    for i in 0..<40 {
                        let target = CGFloat(frame[i]) * CGFloat(config.motionIntensity)
                        // Dynamic interpolation for snappier bass, smoother treble
                        let smoothFactor = 0.2 + (0.1 * (Double(i)/40.0))
                        currentAmplitudes[i] += (target - currentAmplitudes[i]) * CGFloat(smoothFactor)
                    }
                }
            } else {
                // Return to idle state slowly
                for i in 0..<40 {
                    currentAmplitudes[i] += (0.01 - currentAmplitudes[i]) * 0.05
                }
            }
        }
    }
}

struct AmbientParticles: View {
    let phase: Double
    let bassAmp: CGFloat
    let color1: Color
    let color2: Color
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            // Reduced count to 45 for a cleaner, premium, less messy look
            for i in 0..<45 {
                // Pseudo-random deterministic seeds
                let seed1 = Double((i * 13) % 100) / 100.0
                let seed2 = Double((i * 37) % 100) / 100.0
                let seed3 = Double((i * 71) % 100) / 100.0
                
                // 3D Z-Depth
                let zDepth = 0.1 + (seed2 * 0.9)
                
                // Elegant Fluid Motion (Smoother, less chaotic swarming)
                let t1 = phase * (0.1 + seed1 * 0.05)
                let t2 = phase * 0.15 + seed2
                let t3 = phase * 0.2 - seed3
                
                let xWave1 = sin(t1 + seed1 * 10.0)
                let xWave2 = cos(t2 * 1.2 + seed2 * 20.0) * 0.4
                let xWave3 = sin(t3 * 1.5 + seed3 * 30.0) * 0.2
                
                let yWave1 = cos(t1 * 1.1 + seed1 * 15.0)
                let yWave2 = sin(t2 * 1.4 + seed2 * 25.0) * 0.4
                let yWave3 = cos(t3 * 1.8 + seed3 * 35.0) * 0.2
                
                // Smooth sweeping FBM noise
                var x = xWave1 + xWave2 + xWave3
                var y = yWave1 + yWave2 + yWave3
                
                // Audio-Reactive Gentle Jitter (Less chaotic, more like a pulse)
                // When bass is high, particles gently drift outward instead of violently jumping
                let explosion = sin(phase * 5.0 + seed1 * 100.0) * Double(bassAmp) * 0.15 * zDepth
                x += explosion * cos(seed2 * 40.0)
                y += explosion * sin(seed2 * 40.0)
                
                // Normalize into screen space
                x = 0.5 + (x * 0.4)
                y = 0.5 + (y * 0.4)
                
                // Add constant base drift (Slow upwards drift like embers or dust)
                x += sin(phase * 0.05 + seed3) * 0.1
                y -= (phase * 0.03 + seed1 * 0.02).truncatingRemainder(dividingBy: 1.0)
                
                // Wrap around edges cleanly
                if x < -0.1 { x += 1.2 } else if x > 1.1 { x -= 1.2 }
                if y < -0.1 { y += 1.2 } else if y > 1.1 { y -= 1.2 }
                
                // Twinkling effect independent per particle
                let twinkle = (sin(phase * (1.5 + seed3 * 3.0) + seed1 * Double.pi * 2.0) + 1.0) / 2.0
                
                let isGlowing = (i % 3 == 0) // Only 33% are glowing highlights to reduce clutter
                let baseSize = 2.0 + (seed2 * 8.0) // Slightly smaller
                let size = baseSize * zDepth * (1.0 + Double(bassAmp) * 1.0) // Expand size on bass
                
                // Subtler opacity (0.05 base to 0.45 peak) so it's not messy
                let opacity = (0.05 + (twinkle * 0.4)) * zDepth * (1.0 + Double(bassAmp) * 0.5)
                let color = isGlowing ? color2 : color1
                
                let rect = CGRect(x: x * w, y: y * h, width: size, height: size)
                let path = Path(ellipseIn: rect)
                
                var pContext = context
                pContext.opacity = min(1.0, opacity)
                
                // Depth-of-field (Bokeh) blur for far or very close particles
                var blurRadius: Double = 0
                if zDepth > 0.8 {
                    blurRadius = (zDepth - 0.8) * 20.0
                } else if zDepth < 0.3 {
                    blurRadius = (0.3 - zDepth) * 15.0
                }
                
                if blurRadius > 0 {
                    pContext.addFilter(.blur(radius: blurRadius))
                }
                if isGlowing {
                    pContext.addFilter(.shadow(color: color, radius: size * 1.5))
                }
                
                pContext.fill(path, with: .color(color))
            }
        }
    }
}
