import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var timelineWidth: CGFloat = 1000
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: { /* Auto Sync Logic */ }) {
                        Text("AI Sync (Auto)")
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Slider(value: Binding(get: { 1.0 }, set: { _ in }), in: 0.1...5.0)
                        .frame(width: 150)
                }
                .padding(8)
                .background(Color(white: 0.15))
                
                // Track Area
                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color(white: 0.1))
                            .frame(width: max(geo.size.width, timelineWidth), height: 180)
                        
                        // Playhead
                        let playheadX = (store.currentTimeMs / store.state.durationMs) * max(geo.size.width, timelineWidth)
                        if store.state.durationMs > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 180)
                                .offset(x: playheadX)
                        }
                        
                        // Lyrics Blocks
                        ForEach(store.state.lyrics) { lyric in
                            LyricBlockView(lyric: lyric, totalWidth: max(geo.size.width, timelineWidth), durationMs: store.state.durationMs)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard store.state.durationMs > 0 else { return }
                                let percent = max(0, min(1, value.location.x / max(geo.size.width, timelineWidth)))
                                store.seek(to: percent * store.state.durationMs)
                            }
                    )
                }
            }
        }
    }
}

struct LyricBlockView: View {
    let lyric: LyricBlock
    let totalWidth: CGFloat
    let durationMs: Double
    
    var body: some View {
        let startPercent = lyric.startMs / durationMs
        let durationPercent = (lyric.endMs - lyric.startMs) / durationMs
        let x = startPercent * totalWidth
        let w = durationPercent * totalWidth
        
        Text(lyric.text)
            .font(.caption)
            .lineLimit(1)
            .padding(4)
            .frame(width: max(0, w), alignment: .leading)
            .background(Color.blue.opacity(0.4))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .offset(x: x, y: 50)
    }
}
