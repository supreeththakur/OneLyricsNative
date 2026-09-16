import SwiftUI
import AVFoundation

class ProjectStore: ObservableObject {
    @Published var state = ProjectState()
    
    // Player State
    @Published var isPlaying: Bool = false
    @Published var currentTimeMs: Double = 0
    @Published var timelineZoom: CGFloat = 1.0
    
    var player: AVPlayer?
    var timeObserver: Any?
    
    // Fallback duration if audio is not loaded or NaN
    var effectiveDuration: Double {
        if state.durationMs > 0 && !state.durationMs.isNaN { return state.durationMs }
        if let last = state.lyrics.max(by: { $0.endMs < $1.endMs }) {
            return max(last.endMs + 5000, 60000) // Last lyric + 5s, or at least 60s
        }
        return 60000 // 60s default
    }
    
    func setAudio(url: URL) {
        state.audioURL = url
        setupPlayer(url: url)
    }
    
    func setBackground(url: URL) {
        state.backgroundURL = url
    }
    
    func addLyric(_ lyric: LyricBlock) {
        state.lyrics.append(lyric)
        state.lyrics.sort { $0.startMs < $1.startMs }
    }
    
    func removeLyric(id: UUID) {
        state.lyrics.removeAll { $0.id == id }
    }
    
    func clearLyrics() {
        state.lyrics.removeAll()
    }
    
    func shiftAllLyrics(by ms: Double) {
        state.lyrics = state.lyrics.map { lyric in
            var updated = lyric
            updated.startMs = max(0, updated.startMs + ms)
            updated.endMs = max(0, updated.endMs + ms)
            return updated
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to ms: Double) {
        guard let player = player else { return }
        let time = CMTime(seconds: ms / 1000.0, preferredTimescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTimeMs = ms
    }
    
    private func setupPlayer(url: URL) {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        
        // Wait for duration to load async
        Task {
            if let asset = player?.currentItem?.asset {
                do {
                    let duration = try await asset.load(.duration)
                    DispatchQueue.main.async {
                        self.state.durationMs = duration.seconds.isNaN ? 0 : duration.seconds * 1000.0
                    }
                } catch {
                    print("Failed to load duration")
                }
            }
        }
        
        let interval = CMTime(seconds: 0.05, preferredTimescale: 1000)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.isPlaying else { return }
            self.currentTimeMs = time.seconds * 1000.0
            
            let dur = self.player?.currentItem?.duration.seconds ?? 0
            if !dur.isNaN && dur > 0 {
                self.state.durationMs = dur * 1000.0
            }
        }
    }
}
