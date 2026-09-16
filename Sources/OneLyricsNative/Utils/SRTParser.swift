import Foundation

struct SRTParser {
    static func parse(content: String) -> [LyricBlock] {
        var blocks: [LyricBlock] = []
        
        // Normalize line endings
        let normalizedContent = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        // Is it LRC?
        if normalizedContent.contains("[00:") || normalizedContent.contains("[01:") || normalizedContent.contains("[02:") {
            return parseLRC(normalizedContent)
        }
        
        let rawBlocks = normalizedContent.components(separatedBy: "\n\n")
        
        for rawBlock in rawBlocks {
            let lines = rawBlock.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            if lines.count >= 2 {
                // Find the line with "-->"
                if let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) {
                    let timeLine = lines[timeLineIndex]
                    let textLines = lines[(timeLineIndex + 1)...].joined(separator: "\n")
                    
                    let timeParts = timeLine.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                    if timeParts.count == 2 {
                        let startMs = timeStringToMs(timeParts[0])
                        let endMs = timeStringToMs(timeParts[1])
                        blocks.append(LyricBlock(text: textLines, startMs: startMs, endMs: endMs))
                    }
                }
            }
        }
        return blocks
    }
    
    private static func parseLRC(_ content: String) -> [LyricBlock] {
        var blocks: [LyricBlock] = []
        let lines = content.components(separatedBy: .newlines)
        
        // Format: [mm:ss.xx]Text
        let regex = try! NSRegularExpression(pattern: "\\[(\\d{2,3}):(\\d{2})\\.(\\d{2,3})\\](.*)")
        
        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let mm = (line as NSString).substring(with: match.range(at: 1))
                let ss = (line as NSString).substring(with: match.range(at: 2))
                let xx = (line as NSString).substring(with: match.range(at: 3))
                let text = (line as NSString).substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                
                if !text.isEmpty {
                    let mins = Double(mm) ?? 0
                    let secs = Double(ss) ?? 0
                    let msMultiplier = xx.count == 2 ? 10.0 : 1.0
                    let ms = (Double(xx) ?? 0) * msMultiplier
                    
                    let totalMs = (mins * 60000) + (secs * 1000) + ms
                    blocks.append(LyricBlock(text: text, startMs: totalMs, endMs: totalMs + 3000)) 
                }
            }
        }
        
        // Fix LRC durations to last until the next lyric
        for i in 0..<blocks.count {
            if i < blocks.count - 1 {
                blocks[i].endMs = min(blocks[i].startMs + 5000, blocks[i+1].startMs)
            }
        }
        
        return blocks
    }
    
    private static func timeStringToMs(_ timeStr: String) -> Double {
        let cleanStr = timeStr.replacingOccurrences(of: ",", with: ".")
        let components = cleanStr.components(separatedBy: ":")
        
        if components.count == 3 {
            let hh = Double(components[0]) ?? 0
            let mm = Double(components[1]) ?? 0
            let ssParts = components[2].components(separatedBy: ".")
            let ss = Double(ssParts[0]) ?? 0
            let ms = ssParts.count > 1 ? (Double(ssParts[1]) ?? 0) : 0
            return (hh * 3600000) + (mm * 60000) + (ss * 1000) + ms
        } else if components.count == 2 {
            let mm = Double(components[0]) ?? 0
            let ssParts = components[1].components(separatedBy: ".")
            let ss = Double(ssParts[0]) ?? 0
            let ms = ssParts.count > 1 ? (Double(ssParts[1]) ?? 0) : 0
            return (mm * 60000) + (ss * 1000) + ms
        }
        return 0
    }
}
