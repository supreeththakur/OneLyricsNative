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
                ScrollView(.horizontal, showsIndicators: true) {
                    let totalWidth = geo.size.width * store.timelineZoom
                    
                    ZStack(alignment: .leading) {
                        // Background track (Grid-like)
                        Rectangle()
                            .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                            .frame(width: max(geo.size.width, totalWidth), height: 180)
                        
                        // Playhead
                        let playheadX = store.state.durationMs > 0 ? (store.currentTimeMs / store.state.durationMs) * max(geo.size.width, totalWidth) : 0
                        if store.state.durationMs > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 180)
                                .offset(x: playheadX)
                                .zIndex(10)
                        }
                        
                        // Lyrics Blocks
                        ForEach(store.state.lyrics) { lyric in
                            LyricBlockView(lyric: lyric, totalWidth: max(geo.size.width, totalWidth), durationMs: store.state.durationMs)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard store.state.durationMs > 0 else { return }
                                let percent = max(0, min(1, value.location.x / max(geo.size.width, totalWidth)))
                                store.seek(to: percent * store.state.durationMs)
                            }
                    )
                }
                .background(Color(red: 0.05, green: 0.05, blue: 0.06))
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
        .offset(x: x, y: 74)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
