import SwiftUI
import AVKit

struct PlayerView: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        ZStack {
            // Background Layer
            if let bg = store.state.backgroundURL {
                if bg.pathExtension.lowercased() == "mp4" || bg.pathExtension.lowercased() == "mov" {
                    VideoPlayer(player: AVPlayer(url: bg))
                        .disabled(true) // Disable controls
                        .opacity(0.8)
                } else if let nsImage = NSImage(contentsOf: bg) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(0.8)
                }
            } else {
                Color.black
            }
            
            // Lyrics Overlay
            VStack {
                Spacer()
                if let currentLyric = store.state.lyrics.first(where: { store.currentTimeMs >= $0.startMs && store.currentTimeMs <= $0.endMs }) {
                    Text(currentLyric.text)
                        .font(.system(size: store.state.typography.fontSize, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: store.state.typography.color))
                        .shadow(color: .white, radius: store.state.typography.glow)
                        .multilineTextAlignment(.center)
                        .padding()
                        // Animation could go here based on templateId
                        .transition(.opacity)
                }
                Spacer()
            }
            
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
