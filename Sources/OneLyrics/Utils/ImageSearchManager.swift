import Foundation
import AppKit

// MARK: - Common Model

enum ImageProvider: String, CaseIterable, Identifiable {
    case unsplash  = "Unsplash"
    case pixabay   = "Pixabay"
    case pexels    = "Pexels"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .unsplash:  return "photo.on.rectangle"
        case .pixabay:   return "photo.stack.fill"
        case .pexels:    return "rectangle.stack.fill"
        }
    }
    
    var requiresKey: Bool {
        switch self {
        case .unsplash:  return true
        case .pixabay:   return true
        case .pexels:    return true
        }
    }
    
    var keySettingName: String {
        switch self {
        case .unsplash:  return "unsplashAPIKey"
        case .pixabay:   return "pixabayAPIKey"
        case .pexels:    return "pexelsAPIKey"
        }
    }
    
    var getKeyURL: String {
        switch self {
        case .unsplash:  return "https://unsplash.com/developers"
        case .pixabay:   return "https://pixabay.com/api/docs/"
        case .pexels:    return "https://www.pexels.com/api/"
        }
    }
}

struct ImageSearchResult: Identifiable {
    let id: String
    let thumbURL: String
    let fullURL: String
    let authorName: String
    let provider: ImageProvider
    let color: String?
}

// MARK: - Unified Manager

class ImageSearchManager {
    static let shared = ImageSearchManager()

    // MARK: - Search

    func search(query: String, provider: ImageProvider, page: Int = 1) async throws -> [ImageSearchResult] {
        switch provider {
        case .unsplash:  return try await searchUnsplash(query: query, page: page)
        case .pixabay:   return try await searchPixabay(query: query, page: page)
        case .pexels:    return try await searchPexels(query: query, page: page)
        }
    }

    // MARK: - Unsplash (requires free API key from https://unsplash.com/developers)

    private func searchUnsplash(query: String, page: Int) async throws -> [ImageSearchResult] {
        let key = UserDefaults.standard.string(forKey: "unsplashAPIKey") ?? ""
        guard !key.isEmpty else { throw ImageSearchError.noAPIKey("Unsplash") }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.unsplash.com/search/photos?query=\(encoded)&per_page=30&page=\(page)&orientation=landscape") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Client-ID \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("OneLyricsNative/2.0", forHTTPHeaderField: "User-Agent")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageSearchError.apiError("Unsplash HTTP \(httpResp.statusCode): \(body)")
        }

        struct Resp: Codable {
            struct Photo: Codable {
                let id: String
                let color: String?
                let alt_description: String?
                let urls: URLs?
                let user: User?
                struct URLs: Codable {
                    let thumb: String?
                    let regular: String?
                    let full: String?
                }
                struct User: Codable {
                    let name: String?
                }
            }
            let results: [Photo]
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.results.compactMap { p in
            guard let thumb = p.urls?.thumb, let full = p.urls?.regular ?? p.urls?.full else { return nil }
            return ImageSearchResult(id: p.id, thumbURL: thumb, fullURL: full,
                                     authorName: p.user?.name ?? "Unsplash",
                                     provider: .unsplash, color: p.color)
        }
    }

    // MARK: - Pixabay (requires free API key from https://pixabay.com/api/docs/)

    private func searchPixabay(query: String, page: Int) async throws -> [ImageSearchResult] {
        let key = UserDefaults.standard.string(forKey: "pixabayAPIKey") ?? ""
        guard !key.isEmpty else { throw ImageSearchError.noAPIKey("Pixabay") }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://pixabay.com/api/?key=\(key)&q=\(encoded)&image_type=photo&per_page=30&page=\(page)&safesearch=true") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("OneLyricsNative/2.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageSearchError.apiError("Pixabay HTTP \(httpResp.statusCode): \(body)")
        }

        struct Resp: Codable {
            struct Hit: Codable {
                let id: Int
                let previewURL: String?
                let largeImageURL: String?
                let webformatURL: String?
                let user: String?
            }
            let hits: [Hit]
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.hits.compactMap { h in
            guard let thumb = h.previewURL, let full = h.largeImageURL ?? h.webformatURL else { return nil }
            return ImageSearchResult(id: "\(h.id)", thumbURL: thumb, fullURL: full,
                                     authorName: h.user ?? "Pixabay", provider: .pixabay, color: nil)
        }
    }

    // MARK: - Pexels (requires free API key from https://www.pexels.com/api/)

    private func searchPexels(query: String, page: Int) async throws -> [ImageSearchResult] {
        let key = UserDefaults.standard.string(forKey: "pexelsAPIKey") ?? ""
        guard !key.isEmpty else { throw ImageSearchError.noAPIKey("Pexels") }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.pexels.com/v1/search?query=\(encoded)&per_page=30&page=\(page)") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.setValue("OneLyricsNative/2.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            throw ImageSearchError.apiError("Pexels HTTP \(httpResp.statusCode)")
        }

        struct Resp: Codable {
            struct Photo: Codable {
                let id: Int
                let photographer: String?
                let src: Src?
                struct Src: Codable {
                    let medium: String?
                    let large2x: String?
                    let original: String?
                }
            }
            let photos: [Photo]
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.photos.compactMap { p in
            guard let thumb = p.src?.medium, let full = p.src?.large2x ?? p.src?.original else { return nil }
            return ImageSearchResult(id: "\(p.id)", thumbURL: thumb, fullURL: full,
                                     authorName: p.photographer ?? "Pexels", provider: .pexels, color: nil)
        }
    }

    // MARK: - Download

    func downloadImage(_ result: ImageSearchResult) async throws -> URL {
        return try await downloadURL(result.fullURL)
    }

    func downloadURL(_ urlStr: String) async throws -> URL {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (tempURL, _) = try await URLSession.shared.download(for: request)

        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("OneLyricsNative", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        let destination = appDir.appendingPathComponent(UUID().uuidString + ".jpg")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
        return destination
    }
}

// MARK: - Error Types

enum ImageSearchError: LocalizedError {
    case noAPIKey(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "\(provider) API key required. Add it in Settings."
        case .apiError(let msg):
            return msg
        }
    }
}
