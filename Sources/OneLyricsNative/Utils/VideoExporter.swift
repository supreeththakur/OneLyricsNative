import Foundation
import AVFoundation
import AppKit
import CoreGraphics
import SwiftUI

class VideoExporter: ObservableObject {
    @Published var progress: Double = 0
    @Published var isExporting = false
    @Published var exportError: String?
    @Published var exportedURL: URL?
    
    func export(
        store: ProjectStore,
        format: String,
        resolution: String,
        bitrate: String,
        outputURL: URL
    ) {
        isExporting = true
        progress = 0
        exportError = nil
        exportedURL = nil
        
        // Determine video dimensions
        let (width, height): (Int, Int) = {
            switch resolution {
            case "4K": return (3840, 2160)
            case "Vertical": return (1080, 1920)
            default: return (1920, 1080)
            }
        }()
        
        // Determine bitrate
        let avgBitrate: Int = {
            switch bitrate {
            case "Lossless": return 50_000_000
            case "High": return 20_000_000
            default: return 10_000_000
            }
        }()
        
        let fps = Int(store.state.fps)
        let durationMs = store.effectiveDuration
        let totalFrames = Int(durationMs / 1000.0 * Double(fps))
        
        guard totalFrames > 0 else {
            DispatchQueue.main.async {
                self.exportError = "No content to export (duration is 0)"
                self.isExporting = false
            }
            return
        }
        
        // Load background image if present
        var bgImage: NSImage? = nil
        if let bgURL = store.state.backgroundURL {
            let ext = bgURL.pathExtension.lowercased()
            if ext != "mp4" && ext != "mov" {
                bgImage = NSImage(contentsOf: bgURL)
            }
        }
        
        // Prepare lyrics
        let lyrics = store.state.lyrics
        let typography = store.state.typography
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Setup AVAssetWriter
                let fileType: AVFileType = format == "MOV" ? .mov : .mp4
                
                // Delete existing file
                try? FileManager.default.removeItem(at: outputURL)
                
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: format == "MOV" ? AVVideoCodecType.proRes422 : AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: avgBitrate
                    ]
                ]
                
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = false
                
                let pixelAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                ]
                
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: pixelAttrs
                )
                
                // Audio passthrough if audio file exists
                var audioReader: AVAssetReader?
                var audioOutput: AVAssetReaderTrackOutput?
                var audioInput: AVAssetWriterInput?
                
                if let audioURL = store.state.audioURL ?? store.state.backgroundURL {
                    let audioAsset = AVAsset(url: audioURL)
                    let audioTracks = try audioAsset.tracks(withMediaType: .audio)
                    if let audioTrack = audioTracks.first {
                        let reader = try AVAssetReader(asset: audioAsset)
                        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                            AVFormatIDKey: kAudioFormatLinearPCM
                        ])
                        reader.add(output)
                        audioReader = reader
                        audioOutput = output
                        
                        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVSampleRateKey: 44100,
                            AVNumberOfChannelsKey: 2,
                            AVEncoderBitRateKey: 128000
                        ])
                        aInput.expectsMediaDataInRealTime = false
                        audioInput = aInput
                        writer.add(aInput)
                    }
                }
                
                writer.add(videoInput)
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                
                // Render frames
                for frameIndex in 0..<totalFrames {
                    while !videoInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    
                    let currentMs = Double(frameIndex) / Double(fps) * 1000.0
                    
                    // Create pixel buffer
                    guard let pool = adaptor.pixelBufferPool else {
                        throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "No pixel buffer pool"])
                    }
                    
                    var pixelBuffer: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                    guard let buffer = pixelBuffer else { continue }
                    
                    CVPixelBufferLockBaseAddress(buffer, [])
                    
                    // Draw frame using CoreGraphics
                    let context = CGContext(
                        data: CVPixelBufferGetBaseAddress(buffer),
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                    )!
                    
                    // Draw black background
                    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    
                    // Draw background image
                    if let bgImage = bgImage, let cgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        // Scale to fill
                        let imgW = CGFloat(cgImage.width)
                        let imgH = CGFloat(cgImage.height)
                        let canvasW = CGFloat(width)
                        let canvasH = CGFloat(height)
                        let scale = max(canvasW / imgW, canvasH / imgH)
                        let drawW = imgW * scale
                        let drawH = imgH * scale
                        let drawX = (canvasW - drawW) / 2
                        let drawY = (canvasH - drawH) / 2
                        context.draw(cgImage, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
                    }
                    
                    // Draw current lyric text
                    if let currentLyric = lyrics.first(where: { currentMs >= $0.startMs && currentMs <= $0.endMs }) {
                        let text = currentLyric.text as NSString
                        let fontSize = typography.fontSize * CGFloat(width) / 1920.0 // Scale font to resolution
                        
                        // Use NSAttributedString for text rendering
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .center
                        
                        let shadow = NSShadow()
                        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
                        shadow.shadowBlurRadius = typography.glow
                        shadow.shadowOffset = NSSize(width: 0, height: -2)
                        
                        let hexColor = typography.color
                        var cleanHex = hexColor.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                        var rgb: UInt64 = 0
                        Scanner(string: cleanHex).scanHexInt64(&rgb)
                        let nsColor = NSColor(
                            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                            blue: CGFloat(rgb & 0xFF) / 255.0,
                            alpha: 1.0
                        )
                        
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: NSFont.boldSystemFont(ofSize: fontSize),
                            .foregroundColor: nsColor,
                            .paragraphStyle: paragraphStyle,
                            .shadow: shadow
                        ]
                        
                        let textSize = text.size(withAttributes: attrs)
                        let textX = (CGFloat(width) - textSize.width) / 2
                        let textY = CGFloat(height) / 2 - textSize.height / 2
                        
                        // Flip context for text (CoreGraphics is bottom-up)
                        context.saveGState()
                        context.translateBy(x: 0, y: CGFloat(height))
                        context.scaleBy(x: 1, y: -1)
                        
                        // Use NSGraphicsContext to draw attributed string
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
                        text.draw(in: CGRect(x: textX, y: textY, width: textSize.width + 10, height: textSize.height + 10), withAttributes: attrs)
                        NSGraphicsContext.restoreGraphicsState()
                        
                        context.restoreGState()
                    }
                    
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    
                    let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
                    adaptor.append(buffer, withPresentationTime: presentationTime)
                    
                    // Update progress
                    let prog = Double(frameIndex + 1) / Double(totalFrames)
                    if frameIndex % max(1, totalFrames / 100) == 0 {
                        DispatchQueue.main.async {
                            self.progress = prog
                        }
                    }
                }
                
                // Write audio if available
                if let audioReader = audioReader, let audioOutput = audioOutput, let audioInput = audioInput {
                    audioReader.startReading()
                    while let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                        while !audioInput.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.01)
                        }
                        audioInput.append(sampleBuffer)
                    }
                    audioInput.markAsFinished()
                }
                
                videoInput.markAsFinished()
                
                let semaphore = DispatchSemaphore(value: 0)
                writer.finishWriting {
                    semaphore.signal()
                }
                semaphore.wait()
                
                if writer.status == .completed {
                    DispatchQueue.main.async {
                        self.progress = 1.0
                        self.isExporting = false
                        self.exportedURL = outputURL
                    }
                } else {
                    DispatchQueue.main.async {
                        self.exportError = writer.error?.localizedDescription ?? "Unknown export error"
                        self.isExporting = false
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.exportError = error.localizedDescription
                    self.isExporting = false
                }
            }
        }
    }
}
