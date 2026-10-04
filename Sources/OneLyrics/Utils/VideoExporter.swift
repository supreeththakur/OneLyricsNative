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
    @Published var isCancelled = false
    
    func cancel() {
        isCancelled = true
    }
    
    func export(
        state: ProjectState,
        durationMs: Double,
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
        let totalFrames = Int(durationMs / 1000.0 * Double(fps))
        
        guard totalFrames > 0 else {
            exportError = "No content to export (duration is 0)"
            isExporting = false
            return
        }
        
        // Snapshot data from main thread before background execution
        var bgCGImage: CGImage? = nil
        var bgVideoReader: VideoFrameReader? = nil
        
        if let bgURL = state.backgroundURL {
            let ext = bgURL.pathExtension.lowercased()
            if ext == "mp4" || ext == "mov" {
                bgVideoReader = VideoFrameReader(url: bgURL, width: width, height: height)
            } else if let nsImg = NSImage(contentsOf: bgURL) {
                bgCGImage = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
        
        let lyrics = state.lyrics
        let typography = state.typography
        
        // Determine audio source: explicit audio file or background video audio track
        let resolvedAudioURL: URL? = {
            if let a = state.audioURL, FileManager.default.fileExists(atPath: a.path) {
                return a
            }
            if let bg = state.backgroundURL, (bg.pathExtension.lowercased() == "mp4" || bg.pathExtension.lowercased() == "mov") {
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
                    kCVPixelBufferMetalCompatibilityKey as String: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
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
                                mixParams.setVolume(state.mediaConfig.volume, at: .zero)
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
                
                let group = DispatchGroup()
                
                // 3. Start Audio Appending concurrently
                if let aInput = audioInput, let aOutput = audioOutput {
                    group.enter()
                    let audioQueue = DispatchQueue(label: "audioWriterQueue")
                    let maxDurationSec = durationMs / 1000.0
                    aInput.requestMediaDataWhenReady(on: audioQueue) {
                        _ = audioReader // Capture reader to prevent deallocation
                        while aInput.isReadyForMoreMediaData {
                            if self.isCancelled {
                                aInput.markAsFinished()
                                group.leave()
                                break
                            }
                            if let sbuf = aOutput.copyNextSampleBuffer() {
                                let pts = CMSampleBufferGetPresentationTimeStamp(sbuf)
                                if CMTimeGetSeconds(pts) >= maxDurationSec {
                                    aInput.markAsFinished()
                                    group.leave()
                                    break
                                }
                                aInput.append(sbuf)
                            } else {
                                aInput.markAsFinished()
                                group.leave()
                                break
                            }
                        }
                    }
                }
                
                // Use sRGB for CGContext rendering
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little)
                
                let ciContext = CIContext(options: [
                    CIContextOption.useSoftwareRenderer: false,
                    CIContextOption.outputColorSpace: colorSpace,
                    CIContextOption.workingColorSpace: colorSpace
                ])
                let mediaConfig = state.mediaConfig
                
                // --- HOISTED OUT OF LOOP FOR PERFORMANCE ---
                let colorControlsFilter = CIFilter(name: "CIColorControls")
                
                let hexGlow = typography.glowColor?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") ?? "000000"
                var gRgb: UInt64 = 0
                Scanner(string: hexGlow).scanHexInt64(&gRgb)
                let glowR = CGFloat((gRgb & 0xFF0000) >> 16) / 255.0
                let glowG = CGFloat((gRgb & 0x00FF00) >> 8) / 255.0
                let glowB = CGFloat(gRgb & 0x0000FF) / 255.0
                
                let hexStroke = typography.strokeColor.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                var sRgb: UInt64 = 0x000000
                Scanner(string: hexStroke).scanHexInt64(&sRgb)
                let sR = CGFloat((sRgb >> 16) & 0xFF) / 255.0
                let sG = CGFloat((sRgb >> 8) & 0xFF) / 255.0
                let sB = CGFloat(sRgb & 0xFF) / 255.0
                
                let hexColor = typography.color.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                var tRgb: UInt64 = 0
                Scanner(string: hexColor).scanHexInt64(&tRgb)
                let textR = CGFloat((tRgb & 0xFF0000) >> 16) / 255.0
                let textG = CGFloat((tRgb & 0x00FF00) >> 8) / 255.0
                let textB = CGFloat(tRgb & 0x0000FF) / 255.0
                
                let fontSize = typography.fontSize * CGFloat(width) / 1920.0
                let font = NSFont(name: typography.fontFamily, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
                
                let isLeading = typography.alignment == .bottomLeading
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = isLeading ? .left : .center
                let paddingX = typography.edgePadding * (CGFloat(width) / 1920.0)
                let maxTextWidth = CGFloat(width) - (paddingX * 2.0)
                
                var lyricImageCache: [String: CIImage] = [:]
                
                func generateTextCI(_ txt: String) -> CIImage? {
                    if txt.isEmpty { return nil }
                    let displayText = txt as NSString
                    let nsColor = NSColor(red: textR, green: textG, blue: textB, alpha: 1.0)
                    
                    let shadow = NSShadow()
                    if typography.glow > 0 {
                        shadow.shadowColor = NSColor(red: glowR, green: glowG, blue: glowB, alpha: 0.9)
                        shadow.shadowBlurRadius = typography.glow * CGFloat(width) / 1920.0
                        shadow.shadowOffset = NSSize(width: 0, height: -2)
                    }
                    var attrs: [NSAttributedString.Key: Any] = [
                        .font: font, .foregroundColor: nsColor, .paragraphStyle: paragraphStyle
                    ]
                    if typography.glow > 0 { attrs[.shadow] = shadow }
                    
                    let textBounds = displayText.boundingRect(
                        with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attrs, context: nil
                    )
                    
                    // Allocate an image EXACTLY the size of the text (plus padding for glow/stroke)
                    let padding: CGFloat = 100.0
                    let imgW = Int(ceil(textBounds.width + padding*2))
                    let imgH = Int(ceil(textBounds.height + padding*2))
                    
                    guard let bitmapRep = NSBitmapImageRep(
                        bitmapDataPlanes: nil,
                        pixelsWide: imgW,
                        pixelsHigh: imgH,
                        bitsPerSample: 8,
                        samplesPerPixel: 4,
                        hasAlpha: true,
                        isPlanar: false,
                        colorSpaceName: .deviceRGB,
                        bytesPerRow: 0,
                        bitsPerPixel: 0
                    ) else { return nil }
                    
                    guard let textContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else { return nil }
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = textContext
                    
                    NSColor.clear.set()
                    NSRect(x: 0, y: 0, width: imgW, height: imgH).fill()
                    
                    let drawRect = CGRect(x: padding, y: padding, width: textBounds.width + 10, height: textBounds.height + 50)
                    
                    if typography.hasStroke && typography.strokeWidth > 0 {
                        var strokeAttrs = attrs
                        strokeAttrs[.strokeColor] = NSColor(red: sR, green: sG, blue: sB, alpha: 1.0)
                        strokeAttrs[.strokeWidth] = typography.strokeWidth * 2.0
                        displayText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: strokeAttrs, context: nil)
                    }
                    displayText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    
                    NSGraphicsContext.restoreGraphicsState()
                    
                    if let cgImg = bitmapRep.cgImage {
                        return CIImage(cgImage: cgImg)
                    }
                    return nil
                }
                
                // Pre-cache all text images to ensure zero allocation inside the frame loop
                for lyric in lyrics {
                    if typography.animationStyle == .typewriter {
                        for i in 1...lyric.displayText.count {
                            let sub = String(lyric.displayText.prefix(i))
                            if lyricImageCache[sub] == nil {
                                lyricImageCache[sub] = generateTextCI(sub)
                            }
                        }
                    } else {
                        if lyricImageCache[lyric.displayText] == nil {
                            lyricImageCache[lyric.displayText] = generateTextCI(lyric.displayText)
                        }
                    }
                }
                // ------------------------------------
                
                // --- PRE-FILTER STATIC BACKGROUND ---
                var staticBgCI: CIImage? = nil
                if let cgImage = bgCGImage {
                    staticBgCI = CIImage(cgImage: cgImage)
                }
                
                let applyCropToBg = { (ci: CIImage) -> CIImage in
                    let imgW = ci.extent.width
                    let imgH = ci.extent.height
                    let canvasW = CGFloat(width)
                    let canvasH = CGFloat(height)
                    let baseScale = max(canvasW / imgW, canvasH / imgH)
                    let scale = baseScale * CGFloat(mediaConfig.cropScale)
                    let offsetX = CGFloat(mediaConfig.cropOffsetX) * canvasW / 1920.0
                    let offsetY = CGFloat(mediaConfig.cropOffsetY) * canvasH / 1080.0
                    
                    let drawW = imgW * scale
                    let drawH = imgH * scale
                    let drawX = (canvasW - drawW) / 2 + offsetX
                    let drawY = (canvasH - drawH) / 2 - offsetY
                    
                    let transform = CGAffineTransform(translationX: drawX, y: drawY).scaledBy(x: scale, y: scale)
                    return ci.transformed(by: transform).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
                }
                
                if bgVideoReader == nil, let baseCI = staticBgCI {
                    var processedCI = baseCI
                    if mediaConfig.brightness != 0 || mediaConfig.contrast != 1.0 || mediaConfig.saturation != 1.0 {
                        if let filter = colorControlsFilter {
                            filter.setValue(processedCI, forKey: kCIInputImageKey)
                            filter.setValue(CGFloat(mediaConfig.brightness), forKey: kCIInputBrightnessKey)
                            filter.setValue(CGFloat(mediaConfig.contrast), forKey: kCIInputContrastKey)
                            filter.setValue(CGFloat(mediaConfig.saturation), forKey: kCIInputSaturationKey)
                            if let output = filter.outputImage { processedCI = output }
                        }
                    }
                    staticBgCI = applyCropToBg(processedCI)
                }
                // ------------------------------------
                
                // --- HOIST FILTERS & CONSTANTS OUT OF FRAME LOOP ---
                let textAlphaFilter = CIFilter(name: "CIColorMatrix")!
                let textBlurFilter = CIFilter(name: "CIGaussianBlur")!
                let blackBgCI = CIImage(color: CIColor.black).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
                // ---------------------------------------------------
                
                // Render all video frames asynchronously
                group.enter()
                let videoQueue = DispatchQueue(label: "videoWriterQueue")
                var frameIndex = 0
                
                videoInput.requestMediaDataWhenReady(on: videoQueue) {
                    while videoInput.isReadyForMoreMediaData {
                        if frameIndex >= totalFrames || writer.status != .writing || self.isCancelled {
                            videoInput.markAsFinished()
                            group.leave()
                            break
                        }
                        
                        let currentMs = Double(frameIndex) / Double(fps) * 1000.0
                        
                        autoreleasepool {
                            var pixelBuffer: CVPixelBuffer?
                            if let pool = adaptor.pixelBufferPool {
                                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                            }
                            if pixelBuffer == nil {
                                CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, pixelAttrs as CFDictionary, &pixelBuffer)
                            }
                            guard let buffer = pixelBuffer else { return }
                            CVBufferSetAttachment(buffer, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
                            
                            var baseCI: CIImage? = nil
                            
                            if let reader = bgVideoReader, let pb = reader.nextFrame() {
                                var frameCI = CIImage(cvPixelBuffer: pb)
                                if mediaConfig.brightness != 0 || mediaConfig.contrast != 1.0 || mediaConfig.saturation != 1.0 {
                                    if let filter = colorControlsFilter {
                                        filter.setValue(frameCI, forKey: kCIInputImageKey)
                                        filter.setValue(CGFloat(mediaConfig.brightness), forKey: kCIInputBrightnessKey)
                                        filter.setValue(CGFloat(mediaConfig.contrast), forKey: kCIInputContrastKey)
                                        filter.setValue(CGFloat(mediaConfig.saturation), forKey: kCIInputSaturationKey)
                                        if let output = filter.outputImage { frameCI = output }
                                    }
                                }
                                baseCI = applyCropToBg(frameCI)
                            } else {
                                baseCI = staticBgCI
                            }
                            
                            var compositeCI = blackBgCI
                            if let base = baseCI {
                                compositeCI = base.composited(over: compositeCI)
                            }
                            
                            // 3. Lyrics text overlay
                            if let currentLyric = lyrics.first(where: { currentMs >= $0.startMs && currentMs <= $0.endMs }) {
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
                                
                                let txtToDraw: String
                                if anim == .typewriter {
                                    let revealDuration = min((end - start) * 0.5, 1500)
                                    let progress = max(0, min(1, (t - start) / revealDuration))
                                    let charCount = Int(progress * Double(currentLyric.displayText.count))
                                    txtToDraw = String(currentLyric.displayText.prefix(charCount))
                                } else {
                                    txtToDraw = currentLyric.displayText
                                }
                                
                                var textCI = lyricImageCache[txtToDraw]
                                if textCI == nil && anim == .typewriter && !txtToDraw.isEmpty {
                                    textCI = generateTextCI(txtToDraw)
                                    lyricImageCache[txtToDraw] = textCI
                                }
                                
                                if let textCI = textCI {
                                    var animatedTextCI = textCI
                                    
                                    // Use extent to avoid slow boundingRect calculations
                                    let padding: CGFloat = 100.0
                                    let textSize = CGSize(width: textCI.extent.width - padding*2, height: textCI.extent.height - padding*2)
                                    
                                    let textX: CGFloat
                                    switch typography.alignment {
                                    case .center: textX = CGFloat(width) / 2.0 - textSize.width / 2.0
                                    case .bottomLeading: textX = paddingX
                                    default: textX = CGFloat(width) / 2.0 - textSize.width / 2.0
                                    }
                                    
                                    let textY: CGFloat
                                    switch typography.alignment {
                                    case .center: textY = CGFloat(height) / 2.0 - textSize.height / 2.0
                                    case .bottomLeading: textY = CGFloat(height) - 100.0 * (CGFloat(height)/1080.0) - textSize.height
                                    case .bottom: textY = CGFloat(height) - 100.0 * (CGFloat(height)/1080.0) - textSize.height
                                    case .top: textY = 100.0 * (CGFloat(height)/1080.0)
                                    }
                                    
                                    let baseX = textX - padding
                                    let baseY = textY - padding
                                    
                                    // Apply Scale around the local center, then Translate to final position
                                    let cx = textCI.extent.width / 2
                                    let cy = textCI.extent.height / 2
                                    var transform = CGAffineTransform(translationX: -cx, y: -cy)
                                    transform = transform.scaledBy(x: scale, y: scale)
                                    transform = transform.translatedBy(x: cx, y: cy)
                                    transform = transform.translatedBy(x: baseX + xOffset, y: baseY + yOffset)
                                    
                                    animatedTextCI = animatedTextCI.transformed(by: transform)
                                    
                                    // Apply Opacity
                                    if textAlpha < 1.0 {
                                        textAlphaFilter.setValue(animatedTextCI, forKey: kCIInputImageKey)
                                        textAlphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: textAlpha), forKey: "inputAVector")
                                        if let out = textAlphaFilter.outputImage { animatedTextCI = out }
                                    }
                                    
                                    // Apply Blur
                                    if blurRadius > 0 {
                                        textBlurFilter.setValue(animatedTextCI, forKey: kCIInputImageKey)
                                        textBlurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
                                        if let out = textBlurFilter.outputImage { animatedTextCI = out }
                                    }
                                    
                                    compositeCI = animatedTextCI.composited(over: compositeCI)
                                }
                            }
                            
                            // Render composite to pixel buffer using Hardware Accelerated CoreImage
                            ciContext.render(compositeCI, to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: colorSpace)
                            
                            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
                            if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                                print("Failed to append frame \(frameIndex)")
                            }
                        }
                        
                        if frameIndex % max(1, totalFrames / 100) == 0 {
                            let prog = (Double(frameIndex + 1) / Double(totalFrames)) * 0.95
                            DispatchQueue.main.async {
                                self.progress = prog
                            }
                        }
                        frameIndex += 1
                    }
                }
                
                group.notify(queue: .main) {
                    if self.isCancelled {
                        writer.cancelWriting()
                        self.isExporting = false
                        self.progress = 0
                        self.exportError = "Export cancelled"
                        try? FileManager.default.removeItem(at: outputURL)
                        return
                    }
                    
                    writer.finishWriting {
                        DispatchQueue.main.async {
                            if writer.status == .completed {
                                self.progress = 1.0
                                self.isExporting = false
                                self.exportedURL = outputURL
                            } else {
                                self.exportError = writer.error?.localizedDescription ?? "Video encoding failed"
                                self.isExporting = false
                            }
                        }
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
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
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
