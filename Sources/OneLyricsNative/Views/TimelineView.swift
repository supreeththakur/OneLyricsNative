import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: { /* Auto Sync Logic */ }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("AI Sync (Auto)")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.gray)
                        Slider(value: $store.timelineZoom, in: 0.5...10.0)
                            .frame(width: 150)
                            .tint(.purple)
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                Divider().background(Color.white.opacity(0.1))
                
                // Track Area
                let totalWidth = max(geo.size.width, geo.size.width * store.timelineZoom)
                
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Ruler (for Scrubbing)
                        TimelineRuler(totalWidth: totalWidth, durationMs: store.effectiveDuration)
                            .frame(height: 30)
                            .background(Color(white: 0.15))
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let percent = max(0, min(1, value.location.x / totalWidth))
                                        store.seek(to: percent * store.effectiveDuration)
                                    }
                            )
                        
                        // Tracks
                        ZStack(alignment: .leading) {
                            // Grid Background
                            Rectangle()
                                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                                .frame(width: totalWidth, height: 180)
                            
                            // Playhead
                            let playheadX = store.effectiveDuration > 0 ? (store.currentTimeMs / store.effectiveDuration) * totalWidth : 0
                            
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 180)
                                .offset(x: playheadX)
                                .zIndex(10)
                            
                            // Lyrics Blocks
                            ForEach(store.state.lyrics) { lyric in
                                LyricBlockView(lyric: lyric, totalWidth: totalWidth, durationMs: store.effectiveDuration)
                            }
                        }
                    }
                }
                .background(Color(red: 0.05, green: 0.05, blue: 0.06))
            }
        }
    }
}

struct TimelineRuler: View {
    let totalWidth: CGFloat
    let durationMs: Double
    
    var body: some View {
        Canvas { context, size in
            guard durationMs > 0 else { return }
            
            // Draw ticks every 5 seconds
            let totalSeconds = durationMs / 1000.0
            let tickCount = Int(totalSeconds / 5.0)
            
            for i in 0...tickCount {
                let x = CGFloat(i * 5) / CGFloat(totalSeconds) * size.width
                
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height - 10))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(Color.gray.opacity(0.5)), lineWidth: 1)
                
                let timeText = String(format: "%02d:%02d", (i * 5) / 60, (i * 5) % 60)
                let text = Text(timeText).font(.system(size: 9)).foregroundColor(.gray)
                context.draw(text, at: CGPoint(x: x + 2, y: size.height - 15), anchor: .bottomLeading)
            }
        }
        .frame(width: totalWidth)
    }
}

struct LyricBlockView: View {
    @EnvironmentObject var store: ProjectStore
    let lyric: LyricBlock
    let totalWidth: CGFloat
    let durationMs: Double
    
    @State private var isHovered = false
    
    var body: some View {
        let startPercent = lyric.startMs / durationMs
        let durationPercent = (lyric.endMs - lyric.startMs) / durationMs
        let x = startPercent * totalWidth
        let w = durationPercent * totalWidth
        
        ZStack(alignment: .topTrailing) {
            Text(lyric.text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(width: max(0, w), height: 32, alignment: .leading)
                .background(Color.blue.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue.opacity(0.8), lineWidth: 1)
                )
            
            if isHovered {
                Button(action: { store.removeLyric(id: lyric.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        .offset(x: x, y: 30) // Positioned nicely within the track
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
