import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var scrubbingPosition: Double? = nil
    @State private var isScrubbing = false
    
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
                    ZStack(alignment: .topLeading) {
                        // Full background - makes whole area clickable
                        Rectangle()
                            .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                            .frame(width: totalWidth, height: 210) // 30 ruler + 180 track
                        
                        // Ruler ticks
                        TimelineRuler(totalWidth: totalWidth, durationMs: store.effectiveDuration)
                            .frame(width: totalWidth, height: 30)
                        
                        // Ruler background tint
                        Rectangle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: totalWidth, height: 30)
                        
                        // Lyrics Blocks (offset by 30 for ruler height)
                        ForEach(store.state.lyrics) { lyric in
                            LyricBlockView(lyric: lyric, totalWidth: totalWidth, durationMs: store.effectiveDuration)
                                .offset(y: 30)
                        }
                        
                        // Playhead (full height)
                        let activeTime = scrubbingPosition ?? store.currentTimeMs
                        let playheadX = store.effectiveDuration > 0 ? (activeTime / store.effectiveDuration) * totalWidth : 0
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 210)
                            .offset(x: playheadX)
                        
                        // Playhead handle (triangle at top)
                        Path { path in
                            path.move(to: CGPoint(x: playheadX - 6, y: 0))
                            path.addLine(to: CGPoint(x: playheadX + 6, y: 0))
                            path.addLine(to: CGPoint(x: playheadX, y: 10))
                            path.closeSubpath()
                        }
                        .fill(Color.red)
                    }
                    .frame(width: totalWidth, height: 210)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isScrubbing = true
                                let percent = max(0, min(1, value.location.x / totalWidth))
                                let ms = percent * store.effectiveDuration
                                scrubbingPosition = ms
                                store.seek(to: ms)
                            }
                            .onEnded { value in
                                isScrubbing = false
                                let percent = max(0, min(1, value.location.x / totalWidth))
                                let ms = percent * store.effectiveDuration
                                scrubbingPosition = nil
                                store.seek(to: ms)
                            }
                    )
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
            
            let totalSeconds = durationMs / 1000.0
            let tickCount = Int(totalSeconds / 5.0)
            
            for i in 0...tickCount {
                let x = CGFloat(i * 5) / CGFloat(totalSeconds) * size.width
                
                // Major tick
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height - 12))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(Color.gray.opacity(0.5)), lineWidth: 1)
                
                // Minor ticks (every second)
                if i < tickCount {
                    for j in 1..<5 {
                        let minorX = CGFloat(i * 5 + j) / CGFloat(totalSeconds) * size.width
                        let minorPath = Path { p in
                            p.move(to: CGPoint(x: minorX, y: size.height - 5))
                            p.addLine(to: CGPoint(x: minorX, y: size.height))
                        }
                        context.stroke(minorPath, with: .color(Color.gray.opacity(0.25)), lineWidth: 0.5)
                    }
                }
                
                let timeText = String(format: "%02d:%02d", (i * 5) / 60, (i * 5) % 60)
                let text = Text(timeText).font(.system(size: 9)).foregroundColor(.gray)
                context.draw(text, at: CGPoint(x: x + 4, y: 4), anchor: .topLeading)
            }
        }
    }
}

struct LyricBlockView: View {
    @EnvironmentObject var store: ProjectStore
    let lyric: LyricBlock
    let totalWidth: CGFloat
    let durationMs: Double
    
    @State private var isHovered = false
    
    var body: some View {
        let startPercent = durationMs > 0 ? lyric.startMs / durationMs : 0
        let durationPercent = durationMs > 0 ? (lyric.endMs - lyric.startMs) / durationMs : 0
        let x = startPercent * totalWidth
        let w = max(20, durationPercent * totalWidth) // Minimum 20px width so blocks are always visible
        
        ZStack(alignment: .topTrailing) {
            Text(lyric.text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(width: w, height: 32, alignment: .leading)
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
        .position(x: x + w/2, y: 90) // center within 180px track area
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
