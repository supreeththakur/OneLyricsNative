import Foundation

struct YTResult: Codable, Identifiable {
    let id: String
    let title: String
    let duration: Double?
    let thumbnail: String?
}

class YTDLManager: ObservableObject {
    static let shared = YTDLManager()
    
    @Published var isDownloadingEngine = false
    @Published var engineDownloadProgress: Double = 0.0
    
    private var executableURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("OneLyricsNative", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDir.appendingPathComponent("yt-dlp_macos")
    }
    
    var isEngineReady: Bool {
        return FileManager.default.fileExists(atPath: executableURL.path)
    }
    
    func downloadEngineIfNeeded() async throws {
        if isEngineReady { return }
        
        DispatchQueue.main.async {
            self.isDownloadingEngine = true
        }
        
        let url = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        
        if FileManager.default.fileExists(atPath: executableURL.path) {
            try FileManager.default.removeItem(at: executableURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: executableURL)
        
        // Make executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", executableURL.path]
        try process.run()
        process.waitUntilExit()
        
        DispatchQueue.main.async {
            self.isDownloadingEngine = false
        }
    }
    
    func search(query: String) async throws -> [YTResult] {
        // 1. Try Lightning-Fast Native Search first
        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") {
            
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let html = String(data: data, encoding: .utf8) {
                
                var results: [YTResult] = []
                let pattern = "\"videoRenderer\":\\{\"videoId\":\"([^\"]+)\".*?\"title\":\\{\"runs\":\\[\\{\"text\":\"(.*?)\"\\}\\].*?\"lengthText\":\\{.*?\"simpleText\":\"([^\"]+)\"\\}"
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsString = html as NSString
                    let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
                    
                    for match in matches {
                        if match.numberOfRanges == 4, results.count < 50 {
                            let id = nsString.substring(with: match.range(at: 1))
                            let title = nsString.substring(with: match.range(at: 2)).replacingOccurrences(of: "\\\"", with: "\"")
                            let durationStr = nsString.substring(with: match.range(at: 3))
                            
                            var duration: Double = 0
                            let parts = durationStr.components(separatedBy: ":")
                            if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                                duration = m * 60 + s
                            } else if parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
                                duration = h * 3600 + m * 60 + s
                            }
                            
                            if !results.contains(where: { $0.id == id }) {
                                results.append(YTResult(id: id, title: title, duration: duration, thumbnail: nil))
                            }
                        }
                    }
                }
                
                if !results.isEmpty {
                    return results // Return instant native results
                }
            }
        }
        
        // 2. Fallback to yt-dlp if native parsing fails or YouTube changes layout
        if !isEngineReady {
            try await downloadEngineIfNeeded()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["-j", "--flat-playlist", "ytsearch50:\(query)"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    var results: [YTResult] = []
                    let decoder = JSONDecoder()
                    
                    for line in lines {
                        if let lineData = line.data(using: .utf8),
                           let obj = try? decoder.decode(YTResult.self, from: lineData) {
                            results.append(obj)
                        }
                    }
                    continuation.resume(returning: results)
                } else {
                    continuation.resume(returning: [])
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func downloadAudio(id: String) async throws -> URL {
        if !isEngineReady {
            try await downloadEngineIfNeeded()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let tempDir = FileManager.default.temporaryDirectory
            let outputFileName = "\(id)_\(UUID().uuidString).m4a"
            let outputURL = tempDir.appendingPathComponent(outputFileName)
            
            let process = Process()
            process.executableURL = executableURL
            
            // Request best m4a audio
            process.arguments = ["-f", "bestaudio[ext=m4a]", "-o", outputURL.path, "--no-part", "https://www.youtube.com/watch?v=\(id)"]
            process.standardOutput = Pipe() // Silence stdout
            process.standardError = Pipe()  // Silence stderr
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: NSError(domain: "YTDLManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download failed or file not found"]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
