import Foundation

struct UnsplashResult: Codable, Identifiable {
    let id: String
    let width: Int?
    let height: Int?
    let color: String?
    let alt_description: String?
    let urls: UnsplashURLs?
    let user: UnsplashUser?
}

struct UnsplashURLs: Codable {
    let raw: String?
    let full: String?
    let regular: String?
    let small: String?
    let thumb: String?
}

struct UnsplashUser: Codable {
    let name: String?
}

struct UnsplashSearchResponse: Codable {
    let results: [UnsplashResult]
}

class UnsplashManager {
    static let shared = UnsplashManager()
    
    func search(query: String, page: Int = 1) async throws -> [UnsplashResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://unsplash.com/napi/search/photos?query=\(encoded)&per_page=30&page=\(page)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("OneLyricsNative/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(UnsplashSearchResponse.self, from: data)
        return response.results
    }
    
    func downloadImage(urlStr: String) async throws -> URL {
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("OneLyricsNative/1.0", forHTTPHeaderField: "User-Agent")
        
        let (tempURL, _) = try await URLSession.shared.download(for: request)
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("OneLyricsNative", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDir.path) {
            try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let destination = appDir.appendingPathComponent(UUID().uuidString + ".jpg")
        try fileManager.moveItem(at: tempURL, to: destination)
        
        return destination
    }
}
