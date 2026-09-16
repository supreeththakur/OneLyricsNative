import SwiftUI
import AVFoundation

class ProjectStore: ObservableObject {
    @Published var state = ProjectState()
    
    // Player State
    @Published var isPlaying: Bool = false
    @Published var currentTimeMs: Double = 0
    
    var player: AVPlayer?
    var timeObserver: Any?
    
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
        
        let interval = CMTime(seconds: 0.05, preferredTimescale: 1000)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.isPlaying else { return }
            self.currentTimeMs = time.seconds * 1000.0
            self.state.durationMs = self.player?.currentItem?.duration.seconds ?? 0 * 1000.0
        }
    }
}
