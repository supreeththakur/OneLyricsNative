import Foundation
import Cocoa

struct ColorPalette {
    let bg1: String
    let bg2: String
    let fg1: String
    let fg2: String
}

struct ImageColorExtractor {
    static func extractProminentColors(from image: NSImage) -> ColorPalette? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let width = 5
        let height = 5
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(data: &rawData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var colors = [NSColor]()
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = (bytesPerRow * y) + x * bytesPerPixel
                let r = CGFloat(rawData[byteIndex]) / 255.0
                let g = CGFloat(rawData[byteIndex + 1]) / 255.0
                let b = CGFloat(rawData[byteIndex + 2]) / 255.0
                
                if let color = NSColor(red: r, green: g, blue: b, alpha: 1.0).usingColorSpace(.deviceRGB) {
                    if color.brightnessComponent > 0.1 && color.brightnessComponent < 0.95 {
                        colors.append(color)
                    }
                }
            }
        }
        
        if colors.isEmpty {
            return ColorPalette(bg1: "#002222", bg2: "#220022", fg1: "#00FFFF", fg2: "#FF00FF")
        }
        
        let sorted = colors.sorted { c1, c2 in
            return (c1.saturationComponent * c1.brightnessComponent) > (c2.saturationComponent * c2.brightnessComponent)
        }
        
        let c1 = sorted[0]
        var c2 = sorted.count > 1 ? sorted[1] : c1
        
        for i in 1..<sorted.count {
            let candidate = sorted[i]
            let hueDiff = abs(c1.hueComponent - candidate.hueComponent)
            if hueDiff > 0.1 && hueDiff < 0.9 {
                c2 = candidate
                break
            }
        }
        
        // Darken for background so it's subtle and moody
        let bg1 = NSColor(calibratedHue: c1.hueComponent, saturation: c1.saturationComponent * 0.7, brightness: c1.brightnessComponent * 0.3, alpha: 1.0)
        let bg2 = NSColor(calibratedHue: c2.hueComponent, saturation: c2.saturationComponent * 0.7, brightness: c2.brightnessComponent * 0.3, alpha: 1.0)
        
        // Brighten & saturate for foreground so it pops
        let fg1 = NSColor(calibratedHue: c1.hueComponent, saturation: min(1.0, c1.saturationComponent * 1.5), brightness: min(1.0, c1.brightnessComponent * 1.5 + 0.2), alpha: 1.0)
        let fg2 = NSColor(calibratedHue: c2.hueComponent, saturation: min(1.0, c2.saturationComponent * 1.5), brightness: min(1.0, c2.brightnessComponent * 1.5 + 0.2), alpha: 1.0)
        
        return ColorPalette(bg1: bg1.hexString, bg2: bg2.hexString, fg1: fg1.hexString, fg2: fg2.hexString)
    }
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.deviceRGB) else { return "#FFFFFF" }
        let r = Int(max(0, min(255, round(rgb.redComponent * 255))))
        let g = Int(max(0, min(255, round(rgb.greenComponent * 255))))
        let b = Int(max(0, min(255, round(rgb.blueComponent * 255))))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
