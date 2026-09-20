import SwiftUI
import AVKit

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
                        let text = currentLyric.text
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
                                store.updateLyricText(id: currentLyric.id, newText: editingText)
                                editingLyricId = nil
                            })
                            .focused($isTextFieldFocused)
                            .onChange(of: isTextFieldFocused) { _, isFocused in
                                if !isFocused && editingLyricId == currentLyric.id {
                                    store.updateLyricText(id: currentLyric.id, newText: editingText)
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
                                editingText = currentLyric.text
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
        .onChange(of: store.state.mediaConfig.volume) {
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
