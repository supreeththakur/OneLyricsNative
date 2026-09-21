                let group = DispatchGroup()
                
                // 3. Start Audio Appending concurrently
                if let aInput = audioInput, let aOutput = audioOutput {
                    group.enter()
                    let audioQueue = DispatchQueue(label: "audioWriterQueue")
                    let maxDurationSec = durationMs / 1000.0
                    aInput.requestMediaDataWhenReady(on: audioQueue) {
                        while aInput.isReadyForMoreMediaData {
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
                let mediaConfig = store.state.mediaConfig
                
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
                
                // --- PRE-RENDER LYRICS CACHE ---
                var lyricImageCache: [String: CIImage] = [:]
                let textContextSize = NSSize(width: width, height: height)
                
                func cacheText(_ txt: String) {
                    if lyricImageCache[txt] != nil || txt.isEmpty { return }
                    let nsImage = NSImage(size: textContextSize)
                    nsImage.lockFocus()
                    guard let _ = NSGraphicsContext.current?.cgContext else {
                        nsImage.unlockFocus()
                        return
                    }
                    
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
                    let textSize = textBounds.size
                    
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
                    
                    let drawRect = CGRect(x: textX, y: textY, width: textSize.width + 10, height: textSize.height + 50)
                    
                    if typography.hasStroke && typography.strokeWidth > 0 {
                        var strokeAttrs = attrs
                        strokeAttrs[.strokeColor] = NSColor(red: sR, green: sG, blue: sB, alpha: 1.0)
                        strokeAttrs[.strokeWidth] = typography.strokeWidth * 2.0
                        displayText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: strokeAttrs, context: nil)
                    }
                    displayText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    
                    nsImage.unlockFocus()
                    if let tiffData = nsImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let cgImg = bitmap.cgImage {
                        lyricImageCache[txt] = CIImage(cgImage: cgImg)
                    }
                }
                
                for lyric in lyrics {
                    if typography.animationStyle == .typewriter {
                        for i in 1...lyric.text.count { cacheText(String(lyric.text.prefix(i))) }
                    } else {
                        cacheText(lyric.text)
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
                
                // Render all video frames asynchronously
                group.enter()
                let videoQueue = DispatchQueue(label: "videoWriterQueue")
                var frameIndex = 0
                
                videoInput.requestMediaDataWhenReady(on: videoQueue) {
                    while videoInput.isReadyForMoreMediaData {
                        if frameIndex >= totalFrames || writer.status != .writing {
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
                            
                            var compositeCI = CIImage(color: CIColor.black).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
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
                                    let charCount = Int(progress * Double(currentLyric.text.count))
                                    txtToDraw = String(currentLyric.text.prefix(charCount))
                                } else {
                                    txtToDraw = currentLyric.text
                                }
                                
                                if let textCI = lyricImageCache[txtToDraw] {
                                    var animatedTextCI = textCI
                                    
                                    // Apply Scale and Translation around center
                                    let cx = CGFloat(width) / 2
                                    let cy = CGFloat(height) / 2
                                    var transform = CGAffineTransform(translationX: cx, y: cy)
                                    transform = transform.scaledBy(x: scale, y: scale)
                                    transform = transform.translatedBy(x: -cx, y: -cy)
                                    transform = transform.translatedBy(x: xOffset, y: yOffset)
                                    animatedTextCI = animatedTextCI.transformed(by: transform)
                                    
                                    // Apply Opacity
                                    if textAlpha < 1.0 {
                                        let alphaFilter = CIFilter(name: "CIColorMatrix")!
                                        alphaFilter.setValue(animatedTextCI, forKey: kCIInputImageKey)
                                        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: textAlpha), forKey: "inputAVector")
                                        if let out = alphaFilter.outputImage { animatedTextCI = out }
                                    }
                                    
                                    // Apply Blur
                                    if blurRadius > 0 {
                                        let blurFilter = CIFilter(name: "CIGaussianBlur")!
                                        blurFilter.setValue(animatedTextCI, forKey: kCIInputImageKey)
                                        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
                                        if let out = blurFilter.outputImage { animatedTextCI = out }
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
