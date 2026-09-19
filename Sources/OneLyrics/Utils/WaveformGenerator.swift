import Foundation
import AVFoundation

actor WaveformGenerator {
    
    /// Extracts a downsampled array of normalized amplitude values [0...1] from an audio URL.
    static func generateWaveform(for url: URL, targetSamples: Int = 1000) async -> [Float] {
        return await Task.detached(priority: .userInitiated) {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let frameCount = UInt32(file.length)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    return []
                }
                
                try file.read(into: buffer)
                
                guard let floatChannelData = buffer.floatChannelData else {
                    return []
                }
                
                let channelData = floatChannelData[0]
                let totalFrames = Int(buffer.frameLength)
                
                guard totalFrames > 0 else { return [] }
                
                let samplesPerPixel = max(1, totalFrames / targetSamples)
                var result: [Float] = []
                result.reserveCapacity(targetSamples)
                
                var maxAmplitude: Float = 0
                
                for i in 0..<targetSamples {
                    let startFrame = i * samplesPerPixel
                    let endFrame = min(startFrame + samplesPerPixel, totalFrames)
                    
                    if startFrame >= totalFrames { break }
                    
                    var sum: Float = 0
                    for j in startFrame..<endFrame {
                        sum += abs(channelData[j])
                    }
                    
                    let avg = sum / Float(endFrame - startFrame)
                    result.append(avg)
                    
                    if avg > maxAmplitude {
                        maxAmplitude = avg
                    }
                }
                
                // Normalize
                if maxAmplitude > 0 {
                    for i in 0..<result.count {
                        result[i] = result[i] / maxAmplitude
                    }
                }
                
                return result
            } catch {
                print("Failed to generate waveform: \(error)")
                return []
            }
        }.value
    }
}
