import Foundation
import AVFoundation
import Accelerate

struct AudioAnalysisResult {
    var waveform: [Float]      // 1000 points
    var spectrum: [[Float]]    // N frames of 40 bands
    var spectrumFps: Double    // e.g. 30
}

actor AudioAnalyzer {
    static func analyze(url: URL) async -> AudioAnalysisResult? {
        return await Task.detached(priority: .userInitiated) {
            return analyzeSync(url: url)
        }.value
    }
    
    static func analyzeSync(url: URL) -> AudioAnalysisResult? {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate
            let totalFrames = file.length
            guard totalFrames > 0 else { return nil }
                
                // For waveform (1000 points)
                let waveformSamplesPerPixel = max(1, Int(totalFrames) / 1000)
                var waveform = [Float](repeating: 0, count: 1000)
                
                // For spectrum (30 fps)
                let spectrumFps = 30.0
                let framesPerSpectrum = Int(sampleRate / spectrumFps)
                var spectrum: [[Float]] = []
                
                // FFT Setup
                let fftSize = 1024
                let log2n = vDSP_Length(log2(Float(fftSize)))
                guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
                defer { vDSP_destroy_fftsetup(fftSetup) }
                
                let chunkSize = AVAudioFrameCount(8192) // read in chunks
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else { return nil }
                
                var currentFrame: AVAudioFramePosition = 0
                
                var waveformAccumulator: Float = 0
                var waveformCount = 0
                var currentWaveformPixel = 0
                var maxWaveform: Float = 0
                
                var spectrumBuffer = [Float]()
                
                while currentFrame < totalFrames {
                    let framesToRead = min(AVAudioFramePosition(chunkSize), totalFrames - currentFrame)
                    buffer.frameLength = AVAudioFrameCount(framesToRead)
                    
                    try file.read(into: buffer, frameCount: buffer.frameLength)
                    guard let channelData = buffer.floatChannelData?[0] else { break }
                    let readCount = Int(buffer.frameLength)
                    
                    // Process read frames
                    for i in 0..<readCount {
                        let sample = channelData[i]
                        
                        // 1. Waveform
                        waveformAccumulator += abs(sample)
                        waveformCount += 1
                        if waveformCount >= waveformSamplesPerPixel {
                            if currentWaveformPixel < 1000 {
                                let avg = waveformAccumulator / Float(waveformCount)
                                waveform[currentWaveformPixel] = avg
                                if avg > maxWaveform { maxWaveform = avg }
                                currentWaveformPixel += 1
                            }
                            waveformAccumulator = 0
                            waveformCount = 0
                        }
                        
                        // 2. Spectrum Buffer
                        spectrumBuffer.append(sample)
                        if spectrumBuffer.count >= framesPerSpectrum {
                            // Compute FFT on the first `fftSize` samples
                            var windowed = [Float](repeating: 0, count: fftSize)
                            let copyCount = min(spectrumBuffer.count, fftSize)
                            for j in 0..<copyCount { windowed[j] = spectrumBuffer[j] }
                            
                            // Apply Hann window
                            var window = [Float](repeating: 0, count: fftSize)
                            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
                            vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
                            
                            // Prepare for FFT
                            var realp = [Float](repeating: 0, count: fftSize/2)
                            var imagp = [Float](repeating: 0, count: fftSize/2)
                            var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
                            
                            windowed.withUnsafeBytes { ptr in
                                let asComplex = ptr.bindMemory(to: DSPComplex.self)
                                vDSP_ctoz(asComplex.baseAddress!, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
                            }
                            
                            // Perform FFT
                            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                            
                            // Magnitudes
                            var magnitudes = [Float](repeating: 0, count: fftSize/2)
                            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
                            
                            // Convert magnitudes to 40 bands (using logarithmic scale for human hearing)
                            let bandsCount = 40
                            var bands = [Float](repeating: 0, count: bandsCount)
                            
                            // Logarithmic mapping of frequency bins to bands
                            let minBin: Float = 1.0
                            let maxBin = Float(fftSize / 2)
                            let logMin = log10(minBin)
                            let logMax = log10(maxBin)
                            let logRange = logMax - logMin
                            
                            for b in 0..<bandsCount {
                                let startLog = logMin + (Float(b) / Float(bandsCount)) * logRange
                                let endLog = logMin + (Float(b + 1) / Float(bandsCount)) * logRange
                                let startBin = Int(pow(10, startLog))
                                let endBin = max(startBin + 1, Int(pow(10, endLog)))
                                
                                var bandSum: Float = 0
                                var binCount = 0
                                for j in startBin..<endBin {
                                    if j < magnitudes.count {
                                        bandSum += sqrt(magnitudes[j])
                                        binCount += 1
                                    }
                                }
                                bands[b] = binCount > 0 ? (bandSum / Float(binCount)) : 0
                            }
                            spectrum.append(bands)
                            
                            // clear spectrum buffer
                            spectrumBuffer.removeAll(keepingCapacity: true)
                        }
                    }
                    currentFrame += AVAudioFramePosition(readCount)
                }
                
                // Normalize waveform
                if maxWaveform > 0 {
                    for i in 0..<waveform.count { waveform[i] /= maxWaveform }
                }
                
                // Normalize spectrum
                var maxBand: Float = 0
                for frame in spectrum {
                    for val in frame {
                        if val > maxBand { maxBand = val }
                    }
                }
                if maxBand > 0 {
                    for i in 0..<spectrum.count {
                        for j in 0..<spectrum[i].count {
                            // Apply some non-linear scaling to make it look punchy
                            let normalized = spectrum[i][j] / maxBand
                            spectrum[i][j] = pow(normalized, 0.8) // curve
                        }
                    }
                }
                
                return AudioAnalysisResult(waveform: waveform, spectrum: spectrum, spectrumFps: spectrumFps)
                
            } catch {
                print("Analyzer error: \(error)")
                return nil
            }
    }
}
