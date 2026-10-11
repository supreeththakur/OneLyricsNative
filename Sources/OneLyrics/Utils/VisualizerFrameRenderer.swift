import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import AppKit
import SwiftUI

class VisualizerFrameRenderer {
    let width: Int
    let height: Int
    let fps: Int
    let state: ProjectState
    let spectrum: [[Float]]
    let spectrumFps: Double
    let colorSpace: CGColorSpace
    
    // Aesthetic Tokens
    let c1: NSColor
    let c2: NSColor
    let bgC1: NSColor
    let bgC2: NSColor
    let glow: CGFloat
    let motion: CGFloat
    
    // Pre-loaded Artwork
    private var coverCGImage: CGImage? = nil
    
    // Smoothed amplitudes state
    private var currentAmplitudes: [CGFloat] = Array(repeating: 0.02, count: 40)
    private var phase: Double = 0.0
    
    init(width: Int, height: Int, fps: Int, state: ProjectState, spectrumResult: AudioAnalysisResult?, colorSpace: CGColorSpace) {
        self.width = width
        self.height = height
        self.fps = fps
        self.state = state
        self.spectrum = spectrumResult?.spectrum ?? []
        self.spectrumFps = spectrumResult?.spectrumFps ?? 30.0
        self.colorSpace = colorSpace
        
        let config = state.visualizerConfig
        self.c1 = NSColor(Color(hex: config.color1))
        self.c2 = NSColor(Color(hex: config.color2))
        
        // Background colors
        self.bgC1 = NSColor(Color(hex: config.color1)).withAlphaComponent(0.6)
        self.bgC2 = NSColor(Color(hex: config.color2)).withAlphaComponent(0.5)
        self.glow = CGFloat(config.glowIntensity)
        self.motion = CGFloat(config.motionIntensity)
        
        // Load Cover Image
        if let coverURL = state.coverImageURL, let img = NSImage(contentsOf: coverURL) {
            self.coverCGImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        } else if let bgURL = state.backgroundURL, let img = NSImage(contentsOf: bgURL) {
            self.coverCGImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }
    
    func renderFrame(frameIndex: Int, timeSecs: Double, to buffer: CVPixelBuffer, ciContext: CIContext, baseBgCI: CIImage?) {
        let w = CGFloat(width)
        let h = CGFloat(height)
        let config = state.visualizerConfig
        
        // 1. Advance phase and update smoothed amplitudes
        self.phase = Double(frameIndex) * 0.015
        
        let leadTime = timeSecs + 0.035
        let specIndex = Int(leadTime * spectrumFps)
        
        if specIndex >= 0 && specIndex < spectrum.count {
            let frame = spectrum[specIndex]
            for i in 0..<40 {
                let target = CGFloat(frame[i]) * motion
                if target > currentAmplitudes[i] {
                    // Instant attack
                    currentAmplitudes[i] += (target - currentAmplitudes[i]) * 0.88
                } else {
                    // Smooth decay
                    currentAmplitudes[i] += (target - currentAmplitudes[i]) * 0.18
                }
            }
        } else {
            for i in 0..<40 {
                currentAmplitudes[i] += (0.01 - currentAmplitudes[i]) * 0.08
            }
        }
        
        let globalBassAmp = currentAmplitudes[0...3].reduce(0.0, +) / 4.0
        let coverBass = CGFloat(min(1.0, max(0.0, globalBassAmp * 2.8)))
        let glowFactor = glow
        
        // 2. Pre-render blurred background via CoreImage into the buffer
        let blackBgCI = CIImage(color: CIColor.black).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        var compositeBgCI = blackBgCI
        
        if let baseCI = baseBgCI {
            // Heavy blur background like preview
            let blurFilter = CIFilter(name: "CIGaussianBlur")
            blurFilter?.setValue(baseCI, forKey: kCIInputImageKey)
            blurFilter?.setValue(w * 0.08, forKey: kCIInputRadiusKey)
            if let blurred = blurFilter?.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: w, height: h)) {
                let alphaFilter = CIFilter(name: "CIColorMatrix")
                alphaFilter?.setValue(blurred, forKey: kCIInputImageKey)
                alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.4), forKey: "inputAVector")
                if let dim = alphaFilter?.outputImage {
                    compositeBgCI = dim.composited(over: blackBgCI)
                }
            }
        }
        
        ciContext.render(compositeBgCI, to: buffer, bounds: CGRect(x: 0, y: 0, width: w, height: h), colorSpace: colorSpace)
        
        // 3. Draw vector visualizer elements over buffer using hardware-accelerated CGContext
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        guard let ctx = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }
        
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx
        
        // --- LIQUID MOVING BACKGROUND ORBS ---
        drawMovingOrb(ctx: ctx, center: CGPoint(x: w * 0.5 + cos(phase * 0.2) * w * 0.3, y: h * 0.5 + sin(phase * 0.15) * h * 0.3), radius: w * 0.4, color: bgC1.withAlphaComponent(0.55))
        drawMovingOrb(ctx: ctx, center: CGPoint(x: w * 0.5 - cos(phase * 0.18) * w * 0.2, y: h * 0.5 - sin(phase * 0.22) * h * 0.3), radius: w * 0.45, color: bgC2.withAlphaComponent(0.45))
        drawMovingOrb(ctx: ctx, center: CGPoint(x: w * 0.5 + sin(phase * 0.25) * w * 0.4, y: h * 0.5 + cos(phase * 0.2) * h * 0.4), radius: w * 0.3, color: bgC1.withAlphaComponent(0.25))
        
        // Beat-reactive spotlight illuminating the background behind the cover image
        let spotlightPos = CGPoint(x: w * 0.22, y: h * 0.55)
        let spotRadius = w * (0.28 + coverBass * 0.14)
        drawRadialGradient(ctx: ctx, center: spotlightPos, radius: spotRadius, innerColor: c1.withAlphaComponent(0.25 + coverBass * 0.55 * glowFactor), outerColor: .clear)
        
        // --- AMBIENT PARTICLES ---
        drawAmbientParticles(ctx: ctx, w: w, h: h, bassAmp: globalBassAmp)
        
        // --- LEFT SIDE: COVER ART & TEXT OVERLAY ---
        let artworkSize = w * 0.22
        let artworkRect = CGRect(x: w * 0.11, y: h * 0.42, width: artworkSize, height: artworkSize)
        let artworkCenter = CGPoint(x: artworkRect.midX, y: artworkRect.midY)
        
        // 1. Broad Ambient Radial Glow (Chamak) behind cover image
        let chamakRadius = artworkSize * (0.8 + coverBass * 0.45)
        drawRadialGradient(ctx: ctx, center: artworkCenter, radius: chamakRadius, innerColor: c1.withAlphaComponent(0.5 + coverBass * 0.5 * glowFactor), outerColor: .clear)
        
        // 2. High-energy inner bloom halo
        let innerBloomRadius = artworkSize * (0.6 + coverBass * 0.2)
        drawRadialGradient(ctx: ctx, center: artworkCenter, radius: innerBloomRadius, innerColor: c2.withAlphaComponent(0.4 + coverBass * 0.5 * glowFactor), outerColor: .clear)
        
        // 3. Draw Artwork Card (Rounded Rectangle)
        let cornerRadius = artworkSize * 0.14
        let cardPath = CGPath(roundedRect: artworkRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        
        ctx.saveGState()
        ctx.addPath(cardPath)
        ctx.clip()
        
        if let coverImg = coverCGImage {
            ctx.draw(coverImg, in: artworkRect)
        } else {
            ctx.setFillColor(NSColor.darkGray.withAlphaComponent(0.5).cgColor)
            ctx.fill(artworkRect)
        }
        ctx.restoreGState()
        
        // 4. Dynamic Beat-Reactive Glowing Border
        ctx.saveGState()
        ctx.addPath(cardPath)
        ctx.setLineWidth(1.5 + coverBass * 2.5)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.4 + coverBass * 0.6).cgColor)
        ctx.strokePath()
        ctx.restoreGState()
        
        // 5. Text Overlay (Song Title & Artist)
        let fontName = state.typography.fontFamily
        let textCenterX = artworkRect.midX
        var textTopY = artworkRect.minY - 20 // Below artwork in flipped coords
        
        if config.textOverlay.showTitle {
            let titleText = config.textOverlay.title.isEmpty ? (state.title.isEmpty ? "Song Title" : state.title) : config.textOverlay.title
            let titleFontSize = w * 0.038
            let titleFont = NSFont(name: fontName, size: titleFontSize) ?? NSFont.boldSystemFont(ofSize: titleFontSize)
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            
            let titleShadow = NSShadow()
            titleShadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
            titleShadow.shadowBlurRadius = 8
            titleShadow.shadowOffset = NSSize(width: 0, height: -3)
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
                .shadow: titleShadow
            ]
            
            let titleRect = CGRect(x: textCenterX - w * 0.18, y: textTopY - titleFontSize * 1.4, width: w * 0.36, height: titleFontSize * 1.5)
            (titleText as NSString).draw(in: titleRect, withAttributes: titleAttrs)
            textTopY -= (titleFontSize * 1.4 + 10)
        }
        
        if config.textOverlay.showArtist {
            let artistText = config.textOverlay.artist.isEmpty ? "Artist Name" : config.textOverlay.artist
            let artistFontSize = w * 0.020
            let artistFont = NSFont(name: fontName, size: artistFontSize) ?? NSFont.systemFont(ofSize: artistFontSize, weight: .medium)
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            
            let artistAttrs: [NSAttributedString.Key: Any] = [
                .font: artistFont,
                .foregroundColor: NSColor.white.withAlphaComponent(0.75),
                .paragraphStyle: paragraph
            ]
            
            let artistRect = CGRect(x: textCenterX - w * 0.18, y: textTopY - artistFontSize * 1.3, width: w * 0.36, height: artistFontSize * 1.4)
            (artistText as NSString).draw(in: artistRect, withAttributes: artistAttrs)
        }
        
        // --- RIGHT SIDE: VISUALIZER (Bars, Waveform, Circular, Rings) ---
        let vizArea = CGRect(x: w * 0.48, y: h * 0.25, width: w * 0.46, height: h * 0.5)
        
        switch config.type {
        case .spectrumBars:
            drawSpectrumBars(ctx: ctx, rect: vizArea, w: w, h: h)
        case .waveform:
            drawWaveform(ctx: ctx, rect: vizArea, w: w, h: h)
        case .circular:
            drawCircularVisualizer(ctx: ctx, rect: vizArea, w: w, h: h)
        case .frequencyReactive:
            drawFrequencyReactive(ctx: ctx, rect: vizArea, w: w, h: h)
        }
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    // MARK: - Spectrum Bars Drawing
    private func drawSpectrumBars(ctx: CGContext, rect: CGRect, w: CGFloat, h: CGFloat) {
        let barCount = 40
        let totalWidth = rect.width
        let spacing = w * 0.004
        let barWidth = (totalWidth - CGFloat(barCount - 1) * spacing) / CGFloat(barCount)
        let midY = rect.midY
        
        for i in 0..<barCount {
            let amp = max(0.02, currentAmplitudes[i])
            let barHeight = amp * rect.height * 0.9
            let x = rect.minX + CGFloat(i) * (barWidth + spacing)
            let barRect = CGRect(x: x, y: midY - barHeight / 2, width: barWidth, height: barHeight)
            let path = CGPath(roundedRect: barRect, cornerWidth: barWidth * 0.4, cornerHeight: barWidth * 0.4, transform: nil)
            
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            drawLinearGradient(ctx: ctx, from: CGPoint(x: x, y: barRect.minY), to: CGPoint(x: x, y: barRect.maxY), startColor: c1, endColor: c2)
            ctx.restoreGState()
            
            // Subtle stroke
            ctx.addPath(path)
            ctx.setLineWidth(0.8)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
            ctx.strokePath()
        }
    }
    
    // MARK: - Waveform Drawing
    private func drawWaveform(ctx: CGContext, rect: CGRect, w: CGFloat, h: CGFloat) {
        let count = 40
        let step = rect.width / CGFloat(count - 1)
        let midY = rect.midY
        
        // Fill path
        let fillPath = CGMutablePath()
        fillPath.move(to: CGPoint(x: rect.minX, y: midY))
        
        for i in 0..<count {
            let x = rect.minX + CGFloat(i) * step
            let y = midY + (max(0.01, currentAmplitudes[i]) * rect.height * 0.45)
            fillPath.addLine(to: CGPoint(x: x, y: y))
        }
        for i in (0..<count).reversed() {
            let x = rect.minX + CGFloat(i) * step
            let y = midY - (max(0.01, currentAmplitudes[i]) * rect.height * 0.45)
            fillPath.addLine(to: CGPoint(x: x, y: y))
        }
        fillPath.closeSubpath()
        
        ctx.saveGState()
        ctx.addPath(fillPath)
        ctx.clip()
        drawLinearGradient(ctx: ctx, from: CGPoint(x: rect.minX, y: midY), to: CGPoint(x: rect.maxX, y: midY), startColor: c1.withAlphaComponent(0.7), endColor: c2.withAlphaComponent(0.7))
        ctx.restoreGState()
        
        // Center white stroke line
        let strokePath = CGMutablePath()
        strokePath.move(to: CGPoint(x: rect.minX, y: midY))
        for i in 0..<count {
            let x = rect.minX + CGFloat(i) * step
            let y = midY + (max(0.01, currentAmplitudes[i]) * rect.height * 0.45)
            strokePath.addLine(to: CGPoint(x: x, y: y))
        }
        ctx.saveGState()
        ctx.addPath(strokePath)
        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    // MARK: - Circular Trap Nation Visualizer
    private func drawCircularVisualizer(ctx: CGContext, rect: CGRect, w: CGFloat, h: CGFloat) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let bassAmp = currentAmplitudes[0...3].reduce(0, +) / 4.0
        let centerScale = 1.0 + (bassAmp * 0.15)
        let baseRadius = rect.width * 0.18 * centerScale
        
        // Inner Artwork Circle
        ctx.saveGState()
        let innerCircleRect = CGRect(x: center.x - baseRadius, y: center.y - baseRadius, width: baseRadius * 2, height: baseRadius * 2)
        ctx.addEllipse(in: innerCircleRect)
        ctx.clip()
        if let cover = coverCGImage {
            ctx.draw(cover, in: innerCircleRect)
        } else {
            ctx.setFillColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            ctx.fill(innerCircleRect)
        }
        ctx.restoreGState()
        
        // Inner Circle Glowing Border
        ctx.addEllipse(in: innerCircleRect)
        ctx.setLineWidth(4)
        ctx.setStrokeColor(c1.cgColor)
        ctx.strokePath()
        
        // 90 Radial Bars
        let numBars = 90
        for i in 0..<numBars {
            let isRight = i >= (numBars / 2)
            let halfIdx = isRight ? (numBars - 1 - i) : i
            let mappedIdx = min(39, Int((Double(halfIdx) / Double(numBars / 2)) * 39.0))
            
            let amp = max(0.01, currentAmplitudes[mappedIdx])
            let barLength = amp * rect.height * 0.4
            let angle = (Double(i) / Double(numBars)) * Double.pi * 2.0
            
            let startX = center.x + cos(angle) * (baseRadius + 5)
            let startY = center.y + sin(angle) * (baseRadius + 5)
            let endX = center.x + cos(angle) * (baseRadius + 5 + barLength)
            let endY = center.y + sin(angle) * (baseRadius + 5 + barLength)
            
            ctx.saveGState()
            ctx.move(to: CGPoint(x: startX, y: startY))
            ctx.addLine(to: CGPoint(x: endX, y: endY))
            ctx.setLineWidth(w * 0.0035)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(c2.cgColor)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }
    
    // MARK: - Frequency Reactive Rings
    private func drawFrequencyReactive(ctx: CGContext, rect: CGRect, w: CGFloat, h: CGFloat) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let bass = currentAmplitudes[0...3].reduce(0, +) / 4.0
        let mid = currentAmplitudes[10...15].reduce(0, +) / 6.0
        let treble = currentAmplitudes[30...35].reduce(0, +) / 6.0
        
        // Solid Bass Ring
        let bassRadius = w * 0.08 + (bass * w * 0.2)
        ctx.saveGState()
        ctx.addArc(center: center, radius: bassRadius, startAngle: 0, endAngle: Double.pi * 2, clockwise: true)
        ctx.setFillColor(c1.withAlphaComponent(0.75).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        
        // Mid Dashed Stroke Ring
        let midRadius = w * 0.12 + (mid * w * 0.25)
        ctx.saveGState()
        ctx.addArc(center: center, radius: midRadius, startAngle: 0, endAngle: Double.pi * 2, clockwise: true)
        ctx.setLineWidth(w * 0.005 + (mid * w * 0.015))
        let lengths: [CGFloat] = [12, 16]
        ctx.setLineDash(phase: CGFloat(phase * 40), lengths: lengths)
        ctx.setStrokeColor(c2.cgColor)
        ctx.strokePath()
        ctx.restoreGState()
        
        // Treble orbiting points
        for i in 0..<8 {
            let angle = (Double(i) / 8.0) * Double.pi * 2.0 + (phase * 2.0)
            let dotDist = w * 0.16 + (treble * w * 0.1)
            let dotX = center.x + cos(angle) * dotDist
            let dotY = center.y + sin(angle) * dotDist
            let dotSize = w * 0.01 + (treble * w * 0.02)
            
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: dotX - dotSize/2, y: dotY - dotSize/2, width: dotSize, height: dotSize))
        }
    }
    
    // MARK: - Particles Helper
    private func drawAmbientParticles(ctx: CGContext, w: CGFloat, h: CGFloat, bassAmp: CGFloat) {
        for i in 0..<45 {
            let seed1 = Double((i * 13) % 100) / 100.0
            let seed2 = Double((i * 37) % 100) / 100.0
            let seed3 = Double((i * 71) % 100) / 100.0
            
            let zDepth = 0.1 + (seed2 * 0.9)
            let t1 = phase * (0.1 + seed1 * 0.05)
            let t2 = phase * 0.15 + seed2
            
            var x = 0.5 + (sin(t1 + seed1 * 10.0) + cos(t2 * 1.2 + seed2 * 20.0) * 0.4) * 0.4
            var y = 0.5 + (cos(t1 * 1.1 + seed1 * 15.0) + sin(t2 * 1.4 + seed2 * 25.0) * 0.4) * 0.4
            
            y -= (phase * 0.03 + seed1 * 0.02).truncatingRemainder(dividingBy: 1.0)
            if x < -0.1 { x += 1.2 } else if x > 1.1 { x -= 1.2 }
            if y < -0.1 { y += 1.2 } else if y > 1.1 { y -= 1.2 }
            
            let twinkle = (sin(phase * (1.5 + seed3 * 3.0) + seed1 * Double.pi * 2.0) + 1.0) / 2.0
            let isGlowing = (i % 3 == 0)
            let baseSize = 2.0 + (seed2 * 8.0)
            let size = baseSize * zDepth * (1.0 + Double(bassAmp) * 1.0)
            let opacity = (0.05 + (twinkle * 0.4)) * zDepth * (1.0 + Double(bassAmp) * 0.5)
            let color = isGlowing ? c2 : c1
            
            ctx.saveGState()
            ctx.setFillColor(color.withAlphaComponent(min(1.0, opacity)).cgColor)
            ctx.fillEllipse(in: CGRect(x: x * w, y: y * h, width: size, height: size))
            ctx.restoreGState()
        }
    }
    
    // MARK: - Gradient Helpers
    private func drawRadialGradient(ctx: CGContext, center: CGPoint, radius: CGFloat, innerColor: NSColor, outerColor: NSColor) {
        guard let grad = CGGradient(colorsSpace: colorSpace, colors: [innerColor.cgColor, outerColor.cgColor] as CFArray, locations: [0.0, 1.0]) else { return }
        ctx.saveGState()
        ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }
    
    private func drawMovingOrb(ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
        drawRadialGradient(ctx: ctx, center: center, radius: radius, innerColor: color, outerColor: .clear)
    }
    
    private func drawLinearGradient(ctx: CGContext, from: CGPoint, to: CGPoint, startColor: NSColor, endColor: NSColor) {
        guard let grad = CGGradient(colorsSpace: colorSpace, colors: [startColor.cgColor, endColor.cgColor] as CFArray, locations: [0.0, 1.0]) else { return }
        ctx.drawLinearGradient(grad, start: from, end: to, options: [])
    }
}
