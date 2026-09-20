import Foundation
import AppKit
import AVFoundation

class ProjectThumbnailExporter {
    
    /// Generates a thumbnail image from the current project state.
    /// - Parameters:
    ///   - state: The `ProjectState` containing background, typography, and title.
    ///   - textSize: The custom text size for the thumbnail title.
    ///   - size: The target output size (e.g., 1920x1080).
    /// - Returns: A rendered `NSImage`.
    static func generateThumbnail(state: ProjectState, textSize: CGFloat, glow: CGFloat, shadowOffset: CGSize, size: CGSize = CGSize(width: 1920, height: 1080)) async -> NSImage? {
        let bounds = CGRect(origin: .zero, size: size)
        
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let rep = bitmapRep else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        
        // Draw Background
        let cropScale = CGFloat(state.mediaConfig.cropScale)
        
        if let bgURL = state.backgroundURL {
            let ext = bgURL.pathExtension.lowercased()
            var bgImage: CGImage? = nil
            
            if ext == "mp4" || ext == "mov" {
                // Extract first frame
                let asset = AVAsset(url: bgURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2)
                bgImage = try? generator.copyCGImage(at: .zero, actualTime: nil)
            } else {
                // Image background
                if let image = NSImage(contentsOf: bgURL) {
                    bgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                }
            }
            
            if let cgImage = bgImage {
                // Aspect-fill: scale image to cover the entire canvas, then apply cropScale
                let imgW = CGFloat(cgImage.width)
                let imgH = CGFloat(cgImage.height)
                let canvasW = size.width
                let canvasH = size.height
                
                let baseScale = max(canvasW / imgW, canvasH / imgH)
                let finalScale = baseScale * cropScale
                
                // Apply offset (scaled proportionally)
                let offsetX = CGFloat(state.mediaConfig.cropOffsetX) * canvasW / 1920.0
                let offsetY = CGFloat(state.mediaConfig.cropOffsetY) * canvasH / 1080.0
                
                let drawW = imgW * finalScale
                let drawH = imgH * finalScale
                let drawX = (canvasW - drawW) / 2 + offsetX
                let drawY = (canvasH - drawH) / 2 - offsetY // CGContext Y is flipped
                
                context.draw(cgImage, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
            } else {
                context.setFillColor(NSColor.black.cgColor)
                context.fill(bounds)
            }
        } else {
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)
        }
        
        // Draw Text
        let title = state.title.isEmpty ? "New Project" : state.title
        
        // Parse color
        var rgbValue: UInt64 = 0
        let hexColor = state.typography.color.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        Scanner(string: hexColor).scanHexInt64(&rgbValue)
        let color = NSColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
        
        let font = NSFont(name: state.typography.fontFamily, size: textSize) ?? NSFont.systemFont(ofSize: textSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: title, attributes: textAttributes)
        
        // Setup shadow/glow
        context.saveGState()
        if glow > 0 || shadowOffset != .zero {
            var gRgb: UInt64 = 0
            let hexGlow = (state.typography.glowColor ?? "#000000").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
            Scanner(string: hexGlow).scanHexInt64(&gRgb)
            let glowColorObj = NSColor(
                red: CGFloat((gRgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((gRgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(gRgb & 0x0000FF) / 255.0,
                alpha: 1.0
            )
            
            context.setShadow(
                offset: shadowOffset,
                blur: glow,
                color: glowColorObj.cgColor
            )
        }
        
        // Calculate bounds for text
        let textSizeBounds = attributedString.boundingRect(with: size, options: .usesLineFragmentOrigin)
        let textRect = NSRect(
            x: (size.width - textSizeBounds.width) / 2,
            y: (size.height - textSizeBounds.height) / 2,
            width: textSizeBounds.width,
            height: textSizeBounds.height
        )
        
        attributedString.draw(in: textRect)
        
        // Draw stroke if enabled
        if state.typography.hasStroke {
            context.setTextDrawingMode(.stroke)
            context.setLineWidth(2)
            
            var sRgb: UInt64 = 0
            let hexStroke = state.typography.strokeColor.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
            Scanner(string: hexStroke).scanHexInt64(&sRgb)
            let strokeColorObj = NSColor(
                red: CGFloat((sRgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((sRgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(sRgb & 0x0000FF) / 255.0,
                alpha: 1.0
            )
            
            context.setStrokeColor(strokeColorObj.cgColor)
            
            let strokeAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.clear,
                .paragraphStyle: paragraphStyle,
                .strokeColor: strokeColorObj,
                .strokeWidth: -2.0
            ]
            let strokeString = NSAttributedString(string: title, attributes: strokeAttributes)
            strokeString.draw(in: textRect)
        }
        
        context.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
        
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}
