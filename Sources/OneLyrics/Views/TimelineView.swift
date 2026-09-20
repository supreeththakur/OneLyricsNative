import SwiftUI
import AppKit

struct TimelineView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var scrubbingPosition: Double? = nil
    @State private var isScrubbing = false
    @State private var wasPlayingBeforeScrub = false
    @State private var timelineScrollView: NSScrollView?
    @State private var magnifyMonitor: Any?
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: { store.isShowingLyricsFetch = true }) {
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
                    
                    Button(action: {
                        let newLyric = LyricBlock(text: "New Lyric", startMs: store.currentTimeMs, endMs: store.currentTimeMs + 2000)
                        store.addLyric(newLyric)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Text")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 16).background(Color.gray.opacity(0.5)).padding(.horizontal, 8)
                    
                    Button(action: {
                        store.undoManager?.undo()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        store.undoManager?.redo()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.forward")
                            Text("Redo")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
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
                
                ZoomableContainer(onZoom: { magnification in
                    let newZoom = store.timelineZoom + Double(magnification) * store.timelineZoom * 2.0
                    store.timelineZoom = max(0.5, min(20.0, newZoom))
                }) {
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            // Full background - makes whole area clickable
                            Rectangle()
                                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                                .frame(width: totalWidth, height: 300) // 30 ruler + 120 lyrics + 60 wave + 60 thumb + 30 padding
                                
                            ScrollViewExtractor(scrollView: $timelineScrollView)
                                .frame(width: 0, height: 0)
                            
                            // Lyrics Blocks (Offset y: 30)
                            ForEach(store.state.lyrics) { lyric in
                                LyricBlockView(lyric: lyric, totalWidth: totalWidth, durationMs: store.effectiveDuration)
                                    .offset(y: 30)
                            }
                            
                            // Audio Waveform Track (Offset y: 150)
                            WaveformTrackView(totalWidth: totalWidth)
                                .frame(width: totalWidth, height: 60)
                                .offset(y: 150)
                            
                            // Background Video Thumbnails Track (Offset y: 210)
                            ThumbnailTrackView(totalWidth: totalWidth, durationMs: store.effectiveDuration)
                                .frame(width: totalWidth, height: 60)
                                .offset(y: 210)
                            
                            // Ruler background tint
                            Rectangle()
                                .fill(Color.white.opacity(0.03))
                                .frame(width: totalWidth, height: 30)
                                
                            // Ruler ticks
                            TimelineRuler(totalWidth: totalWidth, durationMs: store.effectiveDuration)
                                .frame(width: totalWidth, height: 30)
                            
                            // Playhead (full height)
                            let activeTime = scrubbingPosition ?? store.currentTimeMs
                            let playheadX = store.effectiveDuration > 0 ? (activeTime / store.effectiveDuration) * totalWidth : 0
                            
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 300)
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
                        .frame(width: totalWidth, height: 300)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isScrubbing {
                                        isScrubbing = true
                                        wasPlayingBeforeScrub = store.isPlaying
                                        if wasPlayingBeforeScrub {
                                            store.player?.pause()
                                            store.bgPlayer?.pause()
                                        }
                                    }
                                    let percent = max(0, min(1, value.location.x / totalWidth))
                                    let ms = percent * store.effectiveDuration
                                    scrubbingPosition = ms
                                    store.seek(to: ms, isScrubbing: true)
                                }
                                .onEnded { value in
                                    let percent = max(0, min(1, value.location.x / totalWidth))
                                    let ms = percent * store.effectiveDuration
                                    scrubbingPosition = nil
                                    store.seek(to: ms, isScrubbing: false)
                                    
                                    if wasPlayingBeforeScrub {
                                        store.player?.play()
                                        store.bgPlayer?.play()
                                        wasPlayingBeforeScrub = false
                                    }
                                    isScrubbing = false
                                }
                        )
                    }
                    .background(Color(red: 0.05, green: 0.05, blue: 0.06))
                }
                .onChange(of: store.currentTimeMs) { _ in
                    if store.isPlaying && !isScrubbing {
                        if let nsScrollView = timelineScrollView, let documentView = nsScrollView.documentView {
                            let activeTime = store.currentTimeMs
                            let currentTotalWidth = max(geo.size.width, geo.size.width * store.timelineZoom)
                            let px = store.effectiveDuration > 0 ? (activeTime / store.effectiveDuration) * currentTotalWidth : 0
                            
                            let viewportWidth = nsScrollView.contentSize.width
                            let targetX = px - (viewportWidth / 2.0)
                            
                            let maxOffset = documentView.bounds.width - viewportWidth
                            let safeX = max(0, min(targetX, maxOffset))
                            
                            let currentY = nsScrollView.documentVisibleRect.origin.y
                            documentView.scroll(NSPoint(x: safeX, y: currentY))
                        }
                    }
                }
            }
            .onAppear {
                magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { event in
                    store.timelineZoom = max(0.5, min(20.0, store.timelineZoom + Double(event.magnification) * store.timelineZoom * 2.0))
                    return nil
                }
            }
            .onDisappear {
                if let monitor = magnifyMonitor {
                    NSEvent.removeMonitor(monitor)
                }
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
    @State private var localStartMs: Double? = nil
    @State private var localEndMs: Double? = nil
    @State private var isHoveringLeft = false
    @State private var isHoveringRight = false
    
    var body: some View {
        let activeStart = localStartMs ?? lyric.startMs
        let activeEnd = localEndMs ?? lyric.endMs
        let startPercent = durationMs > 0 ? activeStart / durationMs : 0
        let durationPercent = durationMs > 0 ? (activeEnd - activeStart) / durationMs : 0
        let x = startPercent * totalWidth
        let w = max(20, durationPercent * totalWidth) // Minimum 20px width so blocks are always visible
        
        ZStack(alignment: .topTrailing) {
            ZStack {
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
                    .gesture( // Center drag (move)
                        DragGesture()
                            .onChanged { value in
                                let deltaMs = (value.translation.width / totalWidth) * durationMs
                                localStartMs = max(0, lyric.startMs + deltaMs)
                                localEndMs = max(0, lyric.endMs + deltaMs)
                            }
                            .onEnded { value in
                                if let s = localStartMs, let e = localEndMs {
                                    store.updateLyric(id: lyric.id, newStartMs: s, newEndMs: e)
                                }
                                localStartMs = nil
                                localEndMs = nil
                            }
                    )
                
                HStack(spacing: 0) {
                    // Left resize handle
                    Rectangle()
                        .fill(isHoveringLeft ? Color.yellow.opacity(0.8) : Color.black.opacity(0.01))
                        .frame(width: 12, height: 32)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            isHoveringLeft = hovering
                            if hovering {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let deltaMs = (value.translation.width / totalWidth) * durationMs
                                    localStartMs = min((localEndMs ?? lyric.endMs) - 100, lyric.startMs + deltaMs)
                                }
                                .onEnded { value in
                                    if let newStart = localStartMs {
                                        store.updateLyric(id: lyric.id, newStartMs: newStart, newEndMs: activeEnd)
                                    }
                                    localStartMs = nil
                                }
                        )
                    
                    Spacer()
                    
                    // Right resize handle
                    Rectangle()
                        .fill(isHoveringRight ? Color.yellow.opacity(0.8) : Color.black.opacity(0.01))
                        .frame(width: 12, height: 32)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            isHoveringRight = hovering
                            if hovering {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let deltaMs = (value.translation.width / totalWidth) * durationMs
                                    localEndMs = max((localStartMs ?? lyric.startMs) + 100, lyric.endMs + deltaMs)
                                }
                                .onEnded { value in
                                    if let newEnd = localEndMs {
                                        store.updateLyric(id: lyric.id, newStartMs: activeStart, newEndMs: newEnd)
                                    }
                                    localEndMs = nil
                                }
                        )
                }
                .frame(width: w, height: 32)
            }
            
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
        .offset(x: x, y: 44) // center within 120px lyrics track area (60 - 32/2)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ScrollViewExtractor: NSViewRepresentable {
    @Binding var scrollView: NSScrollView?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.scrollView = view.enclosingScrollView
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ZoomableContainer<Content: View>: NSViewRepresentable {
    var onZoom: (CGFloat) -> Void
    let content: Content

    init(onZoom: @escaping (CGFloat) -> Void, @ViewBuilder content: () -> Content) {
        self.onZoom = onZoom
        self.content = content()
    }

    func makeNSView(context: Context) -> CustomZoomHostingView<Content> {
        let view = CustomZoomHostingView(rootView: content)
        view.onZoom = onZoom
        return view
    }

    func updateNSView(_ nsView: CustomZoomHostingView<Content>, context: Context) {
        nsView.rootView = content
        nsView.onZoom = onZoom
    }
}

class CustomZoomHostingView<Content: View>: NSHostingView<Content> {
    var onZoom: ((CGFloat) -> Void)?
    
    override func magnify(with event: NSEvent) {
        onZoom?(event.magnification)
    }
}

struct WaveformTrackView: View {
    @EnvironmentObject var store: ProjectStore
    let totalWidth: CGFloat
    
    var body: some View {
        ZStack {
            Rectangle().fill(Color(red: 0.1, green: 0.1, blue: 0.12))
            
            if store.waveformData.isEmpty {
                Text(store.isConvertingAudio ? "Converting Audio..." : (store.state.audioURL != nil ? "Loading Waveform..." : "No Audio Track"))
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Canvas { context, size in
                    let data = store.waveformData
                    guard !data.isEmpty else { return }
                    
                    let points = data.count
                    let stepX = size.width / CGFloat(points)
                    let midY = size.height / 2
                    
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: midY))
                    
                    for (i, amplitude) in data.enumerated() {
                        let x = CGFloat(i) * stepX
                        let h = CGFloat(amplitude) * size.height * 0.8 // 80% height max
                        path.addLine(to: CGPoint(x: x, y: midY - h/2))
                    }
                    
                    // Draw bottom half
                    for i in (0..<points).reversed() {
                        let x = CGFloat(i) * stepX
                        let h = CGFloat(data[i]) * size.height * 0.8
                        path.addLine(to: CGPoint(x: x, y: midY + h/2))
                    }
                    
                    path.closeSubpath()
                    context.fill(path, with: .color(.purple.opacity(0.8)))
                }
            }
            
            // Bottom border separator
            VStack {
                Spacer()
                Divider().background(Color.white.opacity(0.05))
            }
        }
    }
}

struct ThumbnailTrackView: View {
    @EnvironmentObject var store: ProjectStore
    let totalWidth: CGFloat
    let durationMs: Double
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color(red: 0.06, green: 0.06, blue: 0.07))
            
            if store.thumbnails.isEmpty {
                Text(store.state.backgroundURL != nil ? (store.bgPlayer != nil ? "Loading Thumbnails..." : "Unsupported Background") : "No Video Track")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if store.thumbnails.count == 1 {
                // Static image background
                ZStack(alignment: .leading) {
                    // Colored block representing the clip duration
                    Rectangle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: totalWidth, height: 50)
                        .cornerRadius(4)
                        .padding(.horizontal, 2)
                        .position(x: totalWidth / 2, y: 30)
                    
                    // Thumbnail at the very beginning
                    Image(nsImage: store.thumbnails[0].image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(4)
                        .clipped()
                        .position(x: 27, y: 30) // Positioned near the left edge
                }
            } else {
                ForEach(0..<store.thumbnails.count, id: \.self) { i in
                    let thumb = store.thumbnails[i]
                    let xPercent = durationMs > 0 ? (thumb.time * 1000.0) / durationMs : 0
                    let xPos = xPercent * totalWidth
                    
                    Image(nsImage: thumb.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .position(x: xPos + 30, y: 30) // Offset to center image correctly
                }
            }
            
            // Bottom border separator
            VStack {
                Spacer()
                Divider().background(Color.white.opacity(0.05))
            }
        }
    }
}

