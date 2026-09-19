import SwiftUI
import AVFoundation

class ProjectStore: ObservableObject {
    @Published var state = ProjectState()
    
    // Player State
    @Published var isPlaying: Bool = false
    @Published var currentTimeMs: Double = 0
    @Published var timelineZoom: CGFloat = 1.0
    @Published var isConvertingAudio: Bool = false
    
    var player: AVPlayer?
    var bgPlayer: AVPlayer? // Player for video backgrounds
    var timeObserver: Any?
    var bgEndObserver: Any?
    var playerEndObserver: Any?
    
    private var isSeeking: Bool = false
    private var pendingSeek: (ms: Double, isScrubbing: Bool)? = nil
    
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
    
    func importAndConvertAudio(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "m4a" || ext == "wav" || ext == "aiff" {
            setAudio(url: url)
            return
        }
        
        isConvertingAudio = true
        Task {
            do {
                let convertedUrl = try await AudioConverter.convertToM4A(sourceURL: url)
                DispatchQueue.main.async {
                    self.setAudio(url: convertedUrl)
                    self.isConvertingAudio = false
                }
            } catch {
                DispatchQueue.main.async {
                    print("Conversion failed: \(error)")
                    self.isConvertingAudio = false
                    self.setAudio(url: url) // Fallback to original
                }
            }
        }
    }
    
    func setBackground(url: URL) {
        state.backgroundURL = url
        if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
            let item = AVPlayerItem(url: url)
            let bp = AVPlayer(playerItem: item)
            bp.actionAtItemEnd = .none
            bgPlayer = bp
            
            // Loop background video automatically
            if let obs = bgEndObserver { NotificationCenter.default.removeObserver(obs) }
            bgEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.bgPlayer?.seek(to: .zero)
                if self?.isPlaying == true {
                    self?.bgPlayer?.play()
                }
            }
            
            // If main audio hasn't been imported, the video acts as the main duration source
            if player == nil {
                setupPlayer(url: url)
            }
        } else {
            bgPlayer = nil
            if let obs = bgEndObserver {
                NotificationCenter.default.removeObserver(obs)
                bgEndObserver = nil
            }
        }
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
        if isPlaying {
            player?.pause()
            bgPlayer?.pause()
            isPlaying = false
        } else {
            // If at end of track, loop back to start
            if currentTimeMs >= effectiveDuration - 200 {
                seek(to: 0, isScrubbing: false)
            }
            player?.play()
            bgPlayer?.play()
            isPlaying = true
        }
    }
    
    func seek(to ms: Double, isScrubbing: Bool = false) {
        guard effectiveDuration > 0 else { return }
        
        let boundedMs = max(0, min(ms, effectiveDuration))
        currentTimeMs = boundedMs
        
        // Prevent queuing dozens of concurrent seeks that stall AVPlayer
        if isSeeking {
            pendingSeek = (ms: boundedMs, isScrubbing: isScrubbing)
            return
        }
        
        isSeeking = true
        let targetMs = boundedMs
        let cmTime = CMTime(seconds: targetMs / 1000.0, preferredTimescale: 1000)
        let tolerance = isScrubbing ? CMTime(seconds: 0.05, preferredTimescale: 1000) : .zero
        
        // Sync background video (looped modulo video duration)
        if let bg = bgPlayer, let item = bg.currentItem {
            let bgDur = CMTimeGetSeconds(item.duration)
            if !bgDur.isNaN && bgDur > 0 {
                let loopSeconds = fmod(targetMs / 1000.0, bgDur)
                let bgTime = CMTime(seconds: loopSeconds, preferredTimescale: 600)
                bg.seek(to: bgTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
            }
        }
        
        // Seek main player
        if let p = player {
            p.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSeeking = false
                    if let pending = self.pendingSeek {
                        self.pendingSeek = nil
                        self.seek(to: pending.ms, isScrubbing: pending.isScrubbing)
                    }
                }
            }
        } else {
            isSeeking = false
        }
    }
    
    private func setupPlayer(url: URL) {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let obs = playerEndObserver {
            NotificationCenter.default.removeObserver(obs)
            self.playerEndObserver = nil
        }
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        player = p
        
        // When song ends, stop playback cleanly and set position to end
        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.isPlaying = false
            self.player?.pause()
            self.bgPlayer?.pause()
            self.currentTimeMs = self.effectiveDuration
        }
        
        // Load duration asynchronously
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durSeconds = CMTimeGetSeconds(duration)
                if !durSeconds.isNaN && durSeconds > 0 {
                    DispatchQueue.main.async {
                        self.state.durationMs = durSeconds * 1000.0
                    }
                }
            } catch {
                print("Failed to load duration from asset: \(error)")
            }
        }
        
        // Periodic time observer for smooth playhead tracking
        let interval = CMTime(seconds: 0.033, preferredTimescale: 1000) // ~30 fps
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            guard self.isPlaying else { return }
            guard !self.isSeeking else { return } // Don't override during seek
            
            let currentSeconds = CMTimeGetSeconds(time)
            if !currentSeconds.isNaN && currentSeconds >= 0 {
                self.currentTimeMs = currentSeconds * 1000.0
            }
            
            // Fallback duration check if not yet populated
            if let dur = self.player?.currentItem?.duration {
                let s = CMTimeGetSeconds(dur)
                if !s.isNaN && s > 0 && (self.state.durationMs == 0 || self.state.durationMs.isNaN) {
                    self.state.durationMs = s * 1000.0
                }
            }
        }
    }
}
