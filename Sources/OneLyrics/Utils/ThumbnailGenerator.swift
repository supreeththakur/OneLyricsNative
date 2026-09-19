import Foundation
import AVFoundation
import AppKit

actor ThumbnailGenerator {
    
    /// Extracts a sequence of images from a video URL.
    static func generateThumbnails(for url: URL, intervalSeconds: Double = 5.0) async -> [(time: Double, image: NSImage)] {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            guard !durationSeconds.isNaN && durationSeconds > 0 else { return [] }
            
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 150, height: 150) // Low res for fast generation
            
            var times: [NSValue] = []
            var currentTime: Double = 0
            
            while currentTime < durationSeconds {
                let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                times.append(NSValue(time: time))
                currentTime += intervalSeconds
            }
            
            // Add the very end frame as well
            times.append(NSValue(time: duration))
            
            return await withCheckedContinuation { continuation in
                var results: [(Double, NSImage)] = []
                var completedCount = 0
                
                generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, actualTime, result, error in
                    let timeSeconds = CMTimeGetSeconds(requestedTime)
                    
                    if let cgImage = image, result == .succeeded {
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        results.append((time: timeSeconds, image: nsImage))
                    }
                    
                    completedCount += 1
                    if completedCount == times.count {
                        // Sort by time
                        results.sort { $0.0 < $1.0 }
                        continuation.resume(returning: results)
                    }
                }
            }
        } catch {
            print("Failed to generate thumbnails: \(error)")
            return []
        }
    }
}
