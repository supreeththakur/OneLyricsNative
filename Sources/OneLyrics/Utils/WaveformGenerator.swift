import Foundation
import AVFoundation

actor WaveformGenerator {
    
    /// Extracts a downsampled array of normalized amplitude values [0...1] from an audio URL.
    static func generateWaveform(for url: URL, targetSamples: Int = 1000) async -> [Float] {
        return await Task.detached(priority: .userInitiated) {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let totalFramesInFile = file.length
                guard totalFramesInFile > 0 else { return [] }
                
                // Read in chunks of 1 second or 100,000 frames
                let chunkSize = AVAudioFrameCount(100_000)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else { return [] }
                
                let samplesPerPixel = max(1, Int(totalFramesInFile) / targetSamples)
                var result = [Float](repeating: 0, count: targetSamples)
                
                var currentFrame: AVAudioFramePosition = 0
                var currentPixel = 0
                
                var framesAccumulatedForPixel = 0
                var sumForPixel: Float = 0
                
                var maxAmplitude: Float = 0
                
                while currentFrame < totalFramesInFile {
                    let framesToRead = min(AVAudioFramePosition(chunkSize), totalFramesInFile - currentFrame)
                    buffer.frameLength = AVAudioFrameCount(framesToRead)
                    
                    do {
                        try file.read(into: buffer, frameCount: buffer.frameLength)
                    } catch {
                        // EOF or read error, break and process what we have
                        break
                    }
                    
                    guard let channelData = buffer.floatChannelData?[0] else { break }
                    let readFrames = Int(buffer.frameLength)
                    
                    for i in 0..<readFrames {
                        sumForPixel += abs(channelData[i])
                        framesAccumulatedForPixel += 1
                        
                        if framesAccumulatedForPixel >= samplesPerPixel {
                            let avg = sumForPixel / Float(framesAccumulatedForPixel)
                            if currentPixel < targetSamples {
                                result[currentPixel] = avg
                                if avg > maxAmplitude { maxAmplitude = avg }
                                currentPixel += 1
                            }
                            sumForPixel = 0
                            framesAccumulatedForPixel = 0
                        }
                    }
                    
                    currentFrame += AVAudioFramePosition(readFrames)
                }
                
                // Process remaining frames for the last pixel
                if framesAccumulatedForPixel > 0 && currentPixel < targetSamples {
                    let avg = sumForPixel / Float(framesAccumulatedForPixel)
                    result[currentPixel] = avg
                    if avg > maxAmplitude { maxAmplitude = avg }
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
