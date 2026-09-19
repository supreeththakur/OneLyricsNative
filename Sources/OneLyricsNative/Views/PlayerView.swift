import SwiftUI
import AVKit

struct PlayerView: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        ZStack {
            // Letterbox background
            Color.black
            
            // 16:9 Canvas - fixed aspect ratio, never changes size with content
            GeometryReader { geo in
                ZStack {
                if let bg = store.state.backgroundURL {
                    if bg.pathExtension.lowercased() == "mp4" || bg.pathExtension.lowercased() == "mov" {
                        if let bgPlayer = store.bgPlayer {
                            Color.clear
                                .overlay(
                                    VideoPlayer(player: bgPlayer)
                                        .disabled(true)
                                )
                                .clipped()
                        }
                    } else if let nsImage = NSImage(contentsOf: bg) {
                        Color.clear
                            .overlay(
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipped()
                    }
                } else {
                    Color(white: 0.1)
                }
                
                // Lyrics Overlay
                let w = geo.size.width
                let scaledFontSize = store.state.typography.fontSize * (w / 1920.0)
                let scaledGlow = store.state.typography.glow * (w / 1920.0)
                
                VStack {
                    Spacer()
                    if let currentLyric = store.state.lyrics.first(where: { store.currentTimeMs >= $0.startMs && store.currentTimeMs <= $0.endMs }) {
                        Text(currentLyric.text)
                            .font(.system(size: scaledFontSize, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: store.state.typography.color))
                            .shadow(color: .black.opacity(0.8), radius: scaledGlow)
                            .multilineTextAlignment(.center)
                            .padding()
                            .transition(.opacity)
                    }
                    Spacer()
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
