import Foundation
import AVFoundation
import AppKit
import CoreGraphics
import CoreImage
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
        
        // Snapshot data from main thread before background execution
        var bgCGImage: CGImage? = nil
        var bgVideoReader: VideoFrameReader? = nil
        
        if let bgURL = store.state.backgroundURL {
            let ext = bgURL.pathExtension.lowercased()
            if ext == "mp4" || ext == "mov" {
                bgVideoReader = VideoFrameReader(url: bgURL, width: width, height: height)
            } else if let nsImg = NSImage(contentsOf: bgURL) {
                bgCGImage = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
        
        let lyrics = store.state.lyrics
        let typography = store.state.typography
        
        // Determine audio source: explicit audio file or background video audio track
        let resolvedAudioURL: URL? = {
            if let a = store.state.audioURL, FileManager.default.fileExists(atPath: a.path) {
                return a
            }
            if let bg = store.state.backgroundURL, (bg.pathExtension.lowercased() == "mp4" || bg.pathExtension.lowercased() == "mov") {
                let asset = AVURLAsset(url: bg)
                if !asset.tracks(withMediaType: .audio).isEmpty {
                    return bg
                }
            }
            return nil
        }()
        
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
                
                // 1. Video Output Setup
                let codec: AVVideoCodecType = format == "MOV" ? .proRes422 : .h264
                var videoSettings: [String: Any] = [
                    AVVideoCodecKey: codec,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height
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
                    kCVPixelBufferCGImageCompatibilityKey as String: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
                ]
                
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: pixelAttrs
                )
                writer.add(videoInput)
                
                // 2. Audio Setup (Read from audio source, encode to AAC directly into output file)
                var audioInput: AVAssetWriterInput? = nil
                var audioReader: AVAssetReader? = nil
                var audioOutput: AVAssetReaderOutput? = nil
                
                if let audioURL = resolvedAudioURL {
                    let audioAsset = AVURLAsset(url: audioURL)
                    if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
                        let aacSettings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVNumberOfChannelsKey: 2,
                            AVSampleRateKey: 44100,
                            AVEncoderBitRateKey: 192000
                        ]
                        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: aacSettings)
                        aInput.expectsMediaDataInRealTime = false
                        
                        if writer.canAdd(aInput) {
                            writer.add(aInput)
                            audioInput = aInput
                            
                            // Setup reader to decode audio to Linear PCM
                            if let reader = try? AVAssetReader(asset: audioAsset) {
                                let pcmSettings: [String: Any] = [
                                    AVFormatIDKey: kAudioFormatLinearPCM,
                                    AVLinearPCMBitDepthKey: 16,
                                    AVLinearPCMIsFloatKey: false,
                                    AVLinearPCMIsBigEndianKey: false,
                                    AVLinearPCMIsNonInterleaved: false
                                ]
                                let aOutput = AVAssetReaderAudioMixOutput(audioTracks: [audioTrack], audioSettings: pcmSettings)
                                
                                let audioMix = AVMutableAudioMix()
                                let mixParams = AVMutableAudioMixInputParameters(track: audioTrack)
                                mixParams.setVolume(store.state.mediaConfig.volume, at: .zero)
                                audioMix.inputParameters = [mixParams]
                                aOutput.audioMix = audioMix
                                
                                if reader.canAdd(aOutput) {
                                    reader.add(aOutput)
                                    audioReader = reader
                                    audioOutput = aOutput
                                }
                            }
                        }
                    }
                }
                
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                audioReader?.startReading()
                
                // 3. Start Audio Appending concurrently
                if let aInput = audioInput, let aOutput = audioOutput {
                    let audioQueue = DispatchQueue(label: "audioWriterQueue")
                    let maxDurationSec = durationMs / 1000.0
                    aInput.requestMediaDataWhenReady(on: audioQueue) {
                        while aInput.isReadyForMoreMediaData {
                            if let sbuf = aOutput.copyNextSampleBuffer() {
                                let pts = CMSampleBufferGetPresentationTimeStamp(sbuf)
                                if CMTimeGetSeconds(pts) >= maxDurationSec {
                                    aInput.markAsFinished()
                                    break
                                }
                                aInput.append(sbuf)
                            } else {
                                aInput.markAsFinished()
                                break
                            }
                        }
                    }
                }
                
                // Use sRGB for CGContext rendering - this is the standard color space for screen-accurate colors.
                // sRGB and BT.709 share the same color primaries, but sRGB uses the correct transfer function
                // for CoreGraphics rendering. This prevents the double-gamma issue that causes washed-out colors.
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                    .union(.byteOrder32Little)
                
                var lastRenderedBgFrame: CGImage? = bgCGImage
                let ciContext = CIContext(options: [
                    CIContextOption.useSoftwareRenderer: false,
                    CIContextOption.outputColorSpace: colorSpace,
                    CIContextOption.workingColorSpace: colorSpace
                ])
                let mediaConfig = store.state.mediaConfig
                
                // Render all video frames
                for frameIndex in 0..<totalFrames {
                    // Wait for input to be ready
                    while !videoInput.isReadyForMoreMediaData {
                        if writer.status != .writing { break }
                        Thread.sleep(forTimeInterval: 0.005)
                    }
                    if writer.status != .writing { break }
                    
                    let currentMs = Double(frameIndex) / Double(fps) * 1000.0
                    
                    autoreleasepool {
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
                            return
                        }
                    }
                    
                    guard let buffer = pixelBuffer else { return }
                    
                    // Attach sRGB color space to pixel buffer so the encoder knows the pixel data is sRGB
                    CVBufferSetAttachment(buffer, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
                    
                    CVPixelBufferLockBaseAddress(buffer, [])
                    
                    guard let context = CGContext(
                        data: CVPixelBufferGetBaseAddress(buffer),
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: colorSpace,
                        bitmapInfo: bitmapInfo.rawValue
                    ) else {
                        CVPixelBufferUnlockBaseAddress(buffer, [])
                        return
                    }
                    
                    // Create reusable text bitmap rep to avoid AppKit Retina scaling bug
                    let textBitmapRep = NSBitmapImageRep(
                        bitmapDataPlanes: nil,
                        pixelsWide: width,
                        pixelsHigh: height,
                        bitsPerSample: 8,
                        samplesPerPixel: 4,
                        hasAlpha: true,
                        isPlanar: false,
                        colorSpaceName: .deviceRGB,
                        bytesPerRow: width * 4,
                        bitsPerPixel: 32
                    )!
                    
                    // 1. Black background fill
                    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    
                    // 2. Background image or video frame
                    if let reader = bgVideoReader, let pb = reader.nextFrame() {
                        // Use CIContext for color-managed conversion to sRGB
                        let ciImg = CIImage(cvPixelBuffer: pb)
                        if let cgImg = ciContext.createCGImage(ciImg, from: ciImg.extent) {
                            lastRenderedBgFrame = cgImg
                        }
                    }
                    
                    if let cgImage = lastRenderedBgFrame {
                        var finalCGImage = cgImage
                        
                        if mediaConfig.brightness != 0 || mediaConfig.contrast != 1.0 || mediaConfig.saturation != 1.0 {
                            let ciImage = CIImage(cgImage: cgImage)
                            var processedCI = ciImage
                            
                            if let filter = CIFilter(name: "CIColorControls") {
                                filter.setValue(processedCI, forKey: kCIInputImageKey)
                                filter.setValue(CGFloat(mediaConfig.brightness), forKey: kCIInputBrightnessKey)
                                filter.setValue(CGFloat(mediaConfig.contrast), forKey: kCIInputContrastKey)
                                filter.setValue(CGFloat(mediaConfig.saturation), forKey: kCIInputSaturationKey)
                                if let output = filter.outputImage {
                                    processedCI = output
                                }
                            }
                            
                            if let rendered = ciContext.createCGImage(processedCI, from: processedCI.extent) {
                                finalCGImage = rendered
                            }
                        }
                        
                        let imgW = CGFloat(finalCGImage.width)
                        let imgH = CGFloat(finalCGImage.height)
                        let canvasW = CGFloat(width)
                        let canvasH = CGFloat(height)
                        
                        // Apply cropScale + offset
                        let baseScale = max(canvasW / imgW, canvasH / imgH)
                        let scale = baseScale * CGFloat(mediaConfig.cropScale)
                        
                        // Scale offset proportionally (offset values are in preview-space ~1920x1080)
                        let offsetX = CGFloat(mediaConfig.cropOffsetX) * canvasW / 1920.0
                        let offsetY = CGFloat(mediaConfig.cropOffsetY) * canvasH / 1080.0
                        
                        let drawW = imgW * scale
                        let drawH = imgH * scale
                        let drawX = (canvasW - drawW) / 2 + offsetX
                        let drawY = (canvasH - drawH) / 2 - offsetY // CGContext Y is flipped
                        context.draw(finalCGImage, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
                    }
                    
                    // 3. Lyrics text overlay
                    if let currentLyric = lyrics.first(where: { currentMs >= $0.startMs && currentMs <= $0.endMs }) {
                        let fontSize = typography.fontSize * CGFloat(width) / 1920.0
                        
                        let anim = typography.animationStyle
                        let t = currentMs
                        let start = currentLyric.startMs
                        let end = currentLyric.endMs
                        
                        let duration = 300.0
                        let progressIn = max(0, min(1, (t - start) / duration))
                        let progressOut = max(0, min(1, (end - t) / duration))
                        
                        let opacity: CGFloat = {
                            if anim == .none { return 1.0 }
                            return CGFloat(min(progressIn, progressOut))
                        }()
                        
                        let scale: CGFloat = {
                            if anim == .pop {
                                let p = progressIn
                                return p < 1 ? CGFloat(0.8 + (p * 0.2)) : 1.0
                            } else if anim == .scaleDown {
                                let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                return CGFloat(1.05 - (totalProgress * 0.05))
                            } else if anim == .scaleUp {
                                let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                return CGFloat(0.95 + (totalProgress * 0.05))
                            }
                            return 1.0
                        }()
                        
                        let blurRadius: CGFloat = {
                            if anim == .blurFade {
                                return CGFloat((1.0 - min(progressIn, progressOut)) * 5.0)
                            }
                            return 0
                        }()
                        
                        let textAlpha: CGFloat = {
                            if anim == .blurFade {
                                let blurProgress = CGFloat(1.0 - min(progressIn, progressOut))
                                return opacity * max(0, (1.0 - blurProgress * 1.5))
                            }
                            return opacity
                        }()
                        
                        let yOffset: CGFloat = {
                            if anim == .slideUp {
                                return CGFloat((1.0 - progressIn) * 50.0 - (1.0 - progressOut) * 50.0)
                            } else if anim == .float {
                                let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                return CGFloat(15.0 - (totalProgress * 30.0))
                            } else if anim == .driftUp {
                                let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                return CGFloat(5.0 - (totalProgress * 10.0))
                            }
                            return 0
                        }()
                        
                        let xOffset: CGFloat = {
                            if anim == .gentleSlide {
                                let totalProgress = max(0, min(1, (t - start) / max(1, end - start)))
                                return CGFloat(-10.0 + (totalProgress * 20.0))
                            }
                            return 0
                        }()
                        
                        let displayText: NSString = {
                            let txt = currentLyric.text
                            if anim == .typewriter {
                                let totalDuration = end - start
                                let revealDuration = min(totalDuration * 0.5, 1500)
                                let progress = max(0, min(1, (t - start) / revealDuration))
                                let charCount = Int(progress * Double(txt.count))
                                return String(txt.prefix(charCount)) as NSString
                            }
                            return txt as NSString
                        }()
                        
                        let isLeading = typography.alignment == .bottomLeading
                        
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = isLeading ? .left : .center
                        
                        let nsColor = NSColor(red: textR, green: textG, blue: textB, alpha: textAlpha)
                        
                        let hexGlow = typography.glowColor?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") ?? "000000"
                        var gRgb: UInt64 = 0
                        Scanner(string: hexGlow).scanHexInt64(&gRgb)
                        let glowR = CGFloat((gRgb & 0xFF0000) >> 16) / 255.0
                        let glowG = CGFloat((gRgb & 0x00FF00) >> 8) / 255.0
                        let glowB = CGFloat(gRgb & 0x0000FF) / 255.0
                        
                        let shadow = NSShadow()
                        if anim == .blurFade && blurRadius > 0 {
                            let blurProgress = CGFloat(1.0 - min(progressIn, progressOut))
                            shadow.shadowColor = NSColor(red: textR, green: textG, blue: textB, alpha: opacity * blurProgress)
                            shadow.shadowBlurRadius = (typography.glow * CGFloat(width) / 1920.0) + blurRadius
                        } else if typography.glow > 0 {
                            shadow.shadowColor = NSColor(red: glowR, green: glowG, blue: glowB, alpha: 0.9 * opacity)
                            shadow.shadowBlurRadius = typography.glow * CGFloat(width) / 1920.0
                            shadow.shadowOffset = NSSize(width: 0, height: -2)
                        }
                        
                        let font = NSFont(name: typography.fontFamily, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
                        
                        var attrs: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: nsColor,
                            .paragraphStyle: paragraphStyle
                        ]
                        
                        if typography.glow > 0 || anim == .blurFade {
                            attrs[.shadow] = shadow
                        }
                        
                        let paddingX = typography.edgePadding * (CGFloat(width) / 1920.0)
                        let maxTextWidth = CGFloat(width) - (paddingX * 2.0)
                        
                        let textBounds = displayText.boundingRect(
                            with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attrs,
                            context: nil
                        )
                        let textSize = textBounds.size
                        
                        let textX: CGFloat
                        switch typography.alignment {
                        case .center: textX = CGFloat(width) / 2.0 - textSize.width / 2.0 + xOffset
                        case .bottomLeading: textX = paddingX + xOffset
                        default: textX = CGFloat(width) / 2.0 - textSize.width / 2.0 + xOffset
                        }
                        
                        let textY: CGFloat
                        switch typography.alignment {
                        case .center: textY = CGFloat(height) / 2.0 - textSize.height / 2.0 + yOffset
                        case .bottomLeading: textY = CGFloat(height) - 100.0 * (CGFloat(height)/1080.0) - textSize.height + yOffset
                        case .bottom: textY = CGFloat(height) - 100.0 * (CGFloat(height)/1080.0) - textSize.height + yOffset
                        case .top: textY = 100.0 * (CGFloat(height)/1080.0) + yOffset
                        }
                        
                        let textRect = NSRect(x: textX, y: textY, width: CGFloat(width), height: textSize.height)
                        
                        // Draw text into textBitmapRep to prevent AppKit retina scaling bug
                        NSGraphicsContext.saveGraphicsState()
                        let baseContext = NSGraphicsContext(bitmapImageRep: textBitmapRep)!
                        let textCGContext = baseContext.cgContext
                        textCGContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
                        
                        textCGContext.saveGState()
                        textCGContext.translateBy(x: 0, y: CGFloat(height))
                        textCGContext.scaleBy(x: 1, y: -1)
                        
                        // Apply Scale transform around center of text
                        let centerX = textX + textSize.width / 2
                        let centerY = textY + textSize.height / 2
                        textCGContext.translateBy(x: centerX, y: centerY)
                        textCGContext.scaleBy(x: scale, y: scale)
                        textCGContext.translateBy(x: -centerX, y: -centerY)
                        
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: textCGContext, flipped: true)
                        let drawRect = CGRect(x: textX, y: textY, width: textSize.width + 10, height: textSize.height + 50)
                        
                        if typography.hasStroke && typography.strokeWidth > 0 {
                            var strokeAttrs = attrs
                            let hexStroke = typography.strokeColor.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                            var sRgb: UInt64 = 0x000000
                            Scanner(string: hexStroke).scanHexInt64(&sRgb)
                            let sR = CGFloat((sRgb >> 16) & 0xFF) / 255.0
                            let sG = CGFloat((sRgb >> 8) & 0xFF) / 255.0
                            let sB = CGFloat(sRgb & 0xFF) / 255.0
                            
                            strokeAttrs[.strokeColor] = NSColor(red: sR, green: sG, blue: sB, alpha: textAlpha)
                            strokeAttrs[.strokeWidth] = typography.strokeWidth * 2.0
                            
                            displayText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: strokeAttrs, context: nil)
                        }
                        
                        displayText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                        textCGContext.restoreGState()
                        NSGraphicsContext.restoreGraphicsState()
                        
                        // Draw the resulting bitmap into our main video context
                        if let cgImage = textBitmapRep.cgImage {
                            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                        }
                    }
                    
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    
                    let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
                    if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                        print("Failed to append frame \(frameIndex): \(writer.error?.localizedDescription ?? "unknown")")
                    }
                    } // end autoreleasepool
                    
                    // Update progress (scale to 0.0 - 0.95 during video render)
                    if frameIndex % max(1, totalFrames / 100) == 0 {
                        let prog = (Double(frameIndex + 1) / Double(totalFrames)) * 0.95
                        DispatchQueue.main.async {
                            self.progress = prog
                        }
                    }
                }
                
                videoInput.markAsFinished()
                
                // Finish writing everything
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
                        let err = writer.error?.localizedDescription ?? "Video encoding failed"
                        self.exportError = err
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

class VideoFrameReader {
    let url: URL
    let width: Int
    let height: Int
    private var asset: AVURLAsset
    private var reader: AVAssetReader?
    private var output: AVAssetReaderTrackOutput?
    
    init(url: URL, width: Int, height: Int) {
        self.url = url
        self.width = width
        self.height = height
        self.asset = AVURLAsset(url: url)
        setupReader()
    }
    
    private func setupReader() {
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        do {
            let newReader = try AVAssetReader(asset: asset)
            let settings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            let newOutput = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
            newOutput.alwaysCopiesSampleData = false
            if newReader.canAdd(newOutput) {
                newReader.add(newOutput)
                newReader.startReading()
                self.reader = newReader
                self.output = newOutput
            }
        } catch {
            print("Failed to setup video reader: \(error)")
        }
    }
    
    func nextFrame() -> CVPixelBuffer? {
        guard let output = output, let reader = reader else { return nil }
        
        if let sampleBuffer = output.copyNextSampleBuffer(),
           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            return pixelBuffer
        } else {
            // Reached end, loop
            reader.cancelReading()
            setupReader()
            
            if let sampleBuffer = self.output?.copyNextSampleBuffer(),
               let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                return pixelBuffer
            }
        }
        return nil
    }
}
