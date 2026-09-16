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
        
        let width: Int
        let height: Int
        switch resolution {
        case "4K": width = 3840; height = 2160
        case "Vertical": width = 1080; height = 1920
        default: width = 1920; height = 1080
        }
        
        let avgBitrate: Int = {
            switch bitrate {
            case "Lossless": return 50_000_000
            case "High": return 20_000_000
            default: return 10_000_000
            }
        }()
        
        let fps = 30
        let durationMs = store.effectiveDuration
        let totalFrames = Int(durationMs / 1000.0 * Double(fps))
        
        guard totalFrames > 0 else {
            exportError = "No content to export (duration is 0)"
            isExporting = false
            return
        }
        
        // Snapshot data from main thread before going to background
        var bgCGImage: CGImage? = nil
        if let bgURL = store.state.backgroundURL {
            let ext = bgURL.pathExtension.lowercased()
            if ext != "mp4" && ext != "mov" {
                if let nsImg = NSImage(contentsOf: bgURL) {
                    bgCGImage = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
                }
            }
        }
        let lyrics = store.state.lyrics
        let typography = store.state.typography
        let audioURL = store.state.audioURL
        
        // Parse text color
        let hexColor = typography.color.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0xFFFFFF
        Scanner(string: hexColor).scanHexInt64(&rgb)
        let textR = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let textG = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let textB = CGFloat(rgb & 0xFF) / 255.0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileType: AVFileType = format == "MOV" ? .mov : .mp4
                try? FileManager.default.removeItem(at: outputURL)
                
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
                
                let codec: AVVideoCodecType = format == "MOV" ? .proRes422 : .h264
                var videoSettings: [String: Any] = [
                    AVVideoCodecKey: codec,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                ]
                if format != "MOV" {
                    videoSettings[AVVideoCompressionPropertiesKey] = [
                        AVVideoAverageBitRateKey: avgBitrate
                    ]
                }
                
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = false
                
                let pixelAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                ]
                
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: pixelAttrs
                )
                
                writer.add(videoInput)
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                
                // Wait for pool to be ready
                var poolReady = false
                for _ in 0..<50 {
                    if adaptor.pixelBufferPool != nil {
                        poolReady = true
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
                
                if !poolReady {
                    // Fallback: create pixel buffer manually for first frame
                    print("Pool not ready, creating manually")
                }
                
                // Render all frames
                for frameIndex in 0..<totalFrames {
                    // Wait for input to be ready
                    while !videoInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.005)
                    }
                    
                    let currentMs = Double(frameIndex) / Double(fps) * 1000.0
                    
                    // Create pixel buffer
                    var pixelBuffer: CVPixelBuffer?
                    if let pool = adaptor.pixelBufferPool {
                        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                    }
                    
                    // Fallback: create manually
                    if pixelBuffer == nil {
                        let status = CVPixelBufferCreate(
                            nil, width, height,
                            kCVPixelFormatType_32BGRA,
                            pixelAttrs as CFDictionary,
                            &pixelBuffer
                        )
                        if status != kCVReturnSuccess {
                            continue
                        }
                    }
                    
                    guard let buffer = pixelBuffer else { continue }
                    
                    CVPixelBufferLockBaseAddress(buffer, [])
                    
                    guard let context = CGContext(
                        data: CVPixelBufferGetBaseAddress(buffer),
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                    ) else {
                        CVPixelBufferUnlockBaseAddress(buffer, [])
                        continue
                    }
                    
                    // 1. Black background
                    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    
                    // 2. Background image (scale to fill)
                    if let cgImage = bgCGImage {
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
                    
                    // 3. Lyrics text
                    if let currentLyric = lyrics.first(where: { currentMs >= $0.startMs && currentMs <= $0.endMs }) {
                        let text = currentLyric.text as NSString
                        let fontSize = typography.fontSize * CGFloat(width) / 1920.0
                        
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .center
                        
                        let nsColor = NSColor(red: textR, green: textG, blue: textB, alpha: 1.0)
                        
                        let shadow = NSShadow()
                        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
                        shadow.shadowBlurRadius = typography.glow
                        shadow.shadowOffset = NSSize(width: 0, height: -2)
                        
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: NSFont.boldSystemFont(ofSize: fontSize),
                            .foregroundColor: nsColor,
                            .paragraphStyle: paragraphStyle,
                            .shadow: shadow
                        ]
                        
                        let textSize = text.size(withAttributes: attrs)
                        let textX = (CGFloat(width) - textSize.width) / 2
                        let textY = CGFloat(height) / 2 - textSize.height / 2
                        
                        // Flip for text drawing
                        context.saveGState()
                        context.translateBy(x: 0, y: CGFloat(height))
                        context.scaleBy(x: 1, y: -1)
                        
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
                        text.draw(
                            in: CGRect(x: textX, y: textY, width: textSize.width + 20, height: textSize.height + 10),
                            withAttributes: attrs
                        )
                        NSGraphicsContext.restoreGraphicsState()
                        context.restoreGState()
                    }
                    
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    
                    let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
                    if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                        print("Failed to append frame \(frameIndex): \(writer.error?.localizedDescription ?? "unknown")")
                    }
                    
                    // Update progress every ~1%
                    if frameIndex % max(1, totalFrames / 100) == 0 {
                        let prog = Double(frameIndex + 1) / Double(totalFrames)
                        DispatchQueue.main.async {
                            self.progress = prog
                        }
                    }
                }
                
                videoInput.markAsFinished()
                
                // Finish writing
                let semaphore = DispatchSemaphore(value: 0)
                writer.finishWriting {
                    semaphore.signal()
                }
                semaphore.wait()
                
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        self.progress = 1.0
                        self.isExporting = false
                        self.exportedURL = outputURL
                    } else {
                        self.exportError = writer.error?.localizedDescription ?? "Export failed"
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
