import Foundation

struct LRCSearchResult: Codable, Identifiable {
    let apiId: Int?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let plainLyrics: String?
    let syncedLyrics: String?
    
    var id: String {
        return "\(apiId ?? 0)_\(UUID().uuidString)"
    }
    
    enum CodingKeys: String, CodingKey {
        case apiId = "id"
        case trackName, artistName, albumName, duration, plainLyrics, syncedLyrics
    }
}

class LRCLibManager {
    static let shared = LRCLibManager()
    
    func search(query: String) async throws -> [LRCSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("OneLyrics Native macOS App (https://github.com/one-lyrics)", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let results = try decoder.decode([LRCSearchResult].self, from: data)
        return results
    }
    
    /// Parses an LRC string and converts it to an array of `LyricBlock`
    func parseLRC(lrcText: String) -> [LyricBlock] {
        let lines = lrcText.components(separatedBy: .newlines)
        var parsedLines: [(ms: Double, text: String)] = []
        
        let regex = try! NSRegularExpression(pattern: "\\[(\\d+):(\\d+(?:\\.\\d+)?)\\](.*)", options: [])
        
        for line in lines {
            let nsRange = NSRange(location: 0, length: line.utf16.count)
            if let match = regex.firstMatch(in: line, options: [], range: nsRange) {
                let nsString = line as NSString
                
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))
                let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let m = Double(minStr), let s = Double(secStr), !text.isEmpty {
                    let totalMs = (m * 60.0 + s) * 1000.0
                    parsedLines.append((ms: totalMs, text: text))
                }
            }
        }
        
        // Sort by time
        parsedLines.sort { $0.ms < $1.ms }
        
        var blocks: [LyricBlock] = []
        for i in 0..<parsedLines.count {
            let current = parsedLines[i]
            let startMs = current.ms
            
            // Determine end time: right before the next line starts, minus 100ms gap
            // If it's the last line, give it a default 4 seconds duration
            var endMs = startMs + 4000.0
            if i + 1 < parsedLines.count {
                let nextMs = parsedLines[i + 1].ms
                endMs = max(startMs + 500, nextMs - 100.0) // At least 500ms duration
            }
            
            let block = LyricBlock(text: current.text, startMs: startMs, endMs: endMs)
            blocks.append(block)
        }
        
        return blocks
    }
}
