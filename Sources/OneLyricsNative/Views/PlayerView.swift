import SwiftUI
import AVKit

struct PlayerView: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Video Background Layer
                Color.black // Letterbox background
                
                ZStack {
                    if let bg = store.state.backgroundURL {
                        if bg.pathExtension.lowercased() == "mp4" || bg.pathExtension.lowercased() == "mov" {
                            if let bgPlayer = store.bgPlayer {
                                Color.clear
                                    .overlay(
                                        VideoPlayer(player: bgPlayer)
                                            .disabled(true)
                                            .opacity(0.8)
                                    )
                                    .clipped()
                            }
                        } else if let nsImage = NSImage(contentsOf: bg) {
                            Color.clear
                                .overlay(
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .opacity(0.8)
                                )
                                .clipped()
                        }
                    } else {
                        Color(white: 0.1) // Default empty player
                    }
                    
                    // Lyrics Overlay
                    VStack {
                        Spacer()
                        if let currentLyric = store.state.lyrics.first(where: { store.currentTimeMs >= $0.startMs && store.currentTimeMs <= $0.endMs }) {
                            Text(currentLyric.text)
                                .font(.system(size: store.state.typography.fontSize, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: store.state.typography.color))
                                .shadow(color: .black.opacity(0.8), radius: store.state.typography.glow) // Black shadow looks better on lyrics for contrast
                                .multilineTextAlignment(.center)
                                .padding()
                                .transition(.opacity)
                        }
                        Spacer()
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(8) // Give the canvas a polished look
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                .padding(20) // Provide padding around the canvas so it doesn't touch the edges
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Playback Controls Overlay (bottom left)
                VStack {
                    Spacer()
                    HStack {
                        Button(action: { store.togglePlayPause() }) {
                            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                        .padding()
                        
                        Text(formatTimecode(ms: store.currentTimeMs))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .background(Color.black.opacity(0.5))
                }
            }
        }
    }
    
    func formatTimecode(ms: Double) -> String {
        let totalSeconds = Int(ms / 1000)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let frames = Int((ms.truncatingRemainder(dividingBy: 1000)) / (1000/30))
        return String(format: "%02d:%02d:%02d", m, s, frames)
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
