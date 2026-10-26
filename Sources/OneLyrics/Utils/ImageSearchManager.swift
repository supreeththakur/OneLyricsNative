import Foundation
import AppKit

// MARK: - Common Model

enum ImageProvider: String, CaseIterable, Identifiable {
    case unsplash  = "Unsplash"
    case openverse = "Openverse"
    case wikimedia = "Wikimedia"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .unsplash:  return "photo.on.rectangle"
        case .openverse: return "photo.stack.fill"
        case .wikimedia: return "globe"
        }
    }

    /// Providers that need a user-supplied API key before searching.
    var requiresKey: Bool {
        switch self {
        case .unsplash:  return true
        case .openverse: return false   // free, no key
        case .wikimedia: return false   // free, no key
        }
    }

    var keySettingName: String {
        switch self {
        case .unsplash:  return "unsplashAPIKey"
        case .openverse: return ""
        case .wikimedia: return ""
        }
    }

    var getKeyURL: String {
        switch self {
        case .unsplash:  return "https://unsplash.com/developers"
        case .openverse: return ""
        case .wikimedia: return ""
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
        case .openverse: return try await searchOpenverse(query: query, page: page)
        case .wikimedia: return try await searchWikimedia(query: query, page: page)
        }
    }

    // MARK: - Unsplash (requires free API key — https://unsplash.com/developers)

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

    // MARK: - Openverse (FREE — no key, CC-licensed, maintained by WordPress)

    private func searchOpenverse(query: String, page: Int) async throws -> [ImageSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openverse.org/v1/images/?q=\(encoded)&page_size=30&page=\(page)&extension=jpg,png&category=photograph") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OneLyricsNative/2.0 (https://github.com/supreeththakur/OneLyricsNative)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            throw ImageSearchError.apiError("Openverse HTTP \(httpResp.statusCode)")
        }

        struct Resp: Codable {
            struct Photo: Codable {
                let id: String
                let url: String?
                let thumbnail: String?
                let creator: String?
            }
            let results: [Photo]
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.results.compactMap { p in
            guard let full = p.url else { return nil }
            let thumb = p.thumbnail ?? full
            return ImageSearchResult(id: p.id, thumbURL: thumb, fullURL: full,
                                     authorName: p.creator ?? "Openverse",
                                     provider: .openverse, color: nil)
        }
    }

    // MARK: - Wikimedia Commons (FREE — no key, massive public-domain collection)

    private func searchWikimedia(query: String, page: Int) async throws -> [ImageSearchResult] {
        let offset = (page - 1) * 30
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrnamespace=6&gsrsearch=\(encoded)%20filetype:bitmap&gsrlimit=30&gsroffset=\(offset)&prop=imageinfo&iiprop=url|mime|extmetadata&iiurlwidth=400&format=json&origin=*") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("OneLyricsNative/2.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            throw ImageSearchError.apiError("Wikimedia HTTP \(httpResp.statusCode)")
        }

        struct Resp: Codable {
            struct Query: Codable {
                struct Page: Codable {
                    let pageid: Int
                    let imageinfo: [ImageInfo]?
                    struct ImageInfo: Codable {
                        let url: String?
                        let thumburl: String?
                        let mime: String?
                        let extmetadata: Meta?
                        struct Meta: Codable {
                            let Artist: MetaValue?
                            struct MetaValue: Codable {
                                let value: String?
                            }
                        }
                    }
                }
                let pages: [String: Page]?
            }
            let query: Query?
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        guard let pages = decoded.query?.pages else { return [] }
        return pages.values.compactMap { page in
            guard let info = page.imageinfo?.first,
                  let mime = info.mime, mime.hasPrefix("image/"),
                  let full = info.url else { return nil }
            let thumb = info.thumburl ?? full
            // Strip HTML tags from artist name
            let rawAuthor = info.extmetadata?.Artist?.value ?? "Wikimedia"
            let author = rawAuthor.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return ImageSearchResult(id: "\(page.pageid)", thumbURL: thumb, fullURL: full,
                                     authorName: author.isEmpty ? "Wikimedia" : author,
                                     provider: .wikimedia, color: nil)
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
