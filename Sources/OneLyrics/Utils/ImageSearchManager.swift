import Foundation
import AppKit

// MARK: - Common Model

enum ImageProvider: String, CaseIterable, Identifiable {
    case unsplash = "Unsplash"
    case pixabay  = "Pixabay"
    case pexels   = "Pexels"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .unsplash: return "camera.fill"
        case .pixabay:  return "photo.stack.fill"
        case .pexels:   return "rectangle.stack.fill"
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
        case .unsplash: return try await searchUnsplash(query: query, page: page)
        case .pixabay:  return try await searchPixabay(query: query, page: page)
        case .pexels:   return try await searchPexels(query: query, page: page)
        }
    }

    // MARK: - Unsplash (Works automatically without API key)

    private func searchUnsplash(query: String, page: Int) async throws -> [ImageSearchResult] {
        // If user has set a custom Unsplash API key, try official API
        let userKey = UserDefaults.standard.string(forKey: "unsplashAPIKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !userKey.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://api.unsplash.com/search/photos?query=\(encoded)&per_page=30&page=\(page)&orientation=landscape") {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Client-ID \(userKey)", forHTTPHeaderField: "Authorization")
            request.setValue("OneLyrics/2.0", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                struct Resp: Codable {
                    struct Photo: Codable {
                        let id: String
                        let color: String?
                        let urls: URLs?
                        let user: User?
                        struct URLs: Codable { let thumb: String?; let regular: String?; let full: String? }
                        struct User: Codable { let name: String? }
                    }
                    let results: [Photo]
                }
                if let decoded = try? JSONDecoder().decode(Resp.self, from: data), !decoded.results.isEmpty {
                    return decoded.results.compactMap { p in
                        guard let thumb = p.urls?.thumb, let full = p.urls?.regular ?? p.urls?.full else { return nil }
                        return ImageSearchResult(id: "un-\(p.id)", thumbURL: thumb, fullURL: full,
                                                 authorName: p.user?.name ?? "Unsplash",
                                                 provider: .unsplash, color: p.color)
                    }
                }
            }
        }

        // Automatic fallback: Public stock photography search (zero API key required)
        let results = try await searchStockCommons(query: "\(query) Unsplash", provider: .unsplash, page: page)
        if !results.isEmpty { return results }
        return try await searchStockCommons(query: "\(query) landscape", provider: .unsplash, page: page)
    }

    // MARK: - Pixabay (Works automatically without API key)

    private func searchPixabay(query: String, page: Int) async throws -> [ImageSearchResult] {
        // If user has set a custom Pixabay API key, try official API
        let userKey = UserDefaults.standard.string(forKey: "pixabayAPIKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !userKey.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://pixabay.com/api/?key=\(userKey)&q=\(encoded)&image_type=photo&per_page=30&page=\(page)&safesearch=true") {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("OneLyrics/2.0", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
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
                if let decoded = try? JSONDecoder().decode(Resp.self, from: data), !decoded.hits.isEmpty {
                    return decoded.hits.compactMap { h in
                        guard let thumb = h.previewURL, let full = h.largeImageURL ?? h.webformatURL else { return nil }
                        return ImageSearchResult(id: "px-\(h.id)", thumbURL: thumb, fullURL: full,
                                                 authorName: h.user ?? "Pixabay",
                                                 provider: .pixabay, color: nil)
                    }
                }
            }
        }

        // Automatic fallback: Public stock photography search (zero API key required)
        let results = try await searchStockCommons(query: "\(query) Pixabay", provider: .pixabay, page: page)
        if !results.isEmpty { return results }
        return try await searchStockCommons(query: "\(query) background", provider: .pixabay, page: page)
    }

    // MARK: - Pexels (Works automatically without API key)

    private func searchPexels(query: String, page: Int) async throws -> [ImageSearchResult] {
        // If user has set a custom Pexels API key, try official API
        let userKey = UserDefaults.standard.string(forKey: "pexelsAPIKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !userKey.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://api.pexels.com/v1/search?query=\(encoded)&per_page=30&page=\(page)") {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue(userKey, forHTTPHeaderField: "Authorization")
            request.setValue("OneLyrics/2.0", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                struct Resp: Codable {
                    struct Photo: Codable {
                        let id: Int
                        let photographer: String?
                        let src: Src?
                        struct Src: Codable { let medium: String?; let large2x: String?; let original: String? }
                    }
                    let photos: [Photo]
                }
                if let decoded = try? JSONDecoder().decode(Resp.self, from: data), !decoded.photos.isEmpty {
                    return decoded.photos.compactMap { p in
                        guard let thumb = p.src?.medium, let full = p.src?.large2x ?? p.src?.original else { return nil }
                        return ImageSearchResult(id: "pe-\(p.id)", thumbURL: thumb, fullURL: full,
                                                 authorName: p.photographer ?? "Pexels",
                                                 provider: .pexels, color: nil)
                    }
                }
            }
        }

        // Automatic fallback: Flickr public feed or stock commons (zero API key required)
        let flickrResults = try await searchFlickr(query: query, provider: .pexels)
        if !flickrResults.isEmpty { return flickrResults }
        return try await searchStockCommons(query: "\(query) Pexels", provider: .pexels, page: page)
    }

    // MARK: - Keyless Public Search Engines

    private func searchStockCommons(query: String, provider: ImageProvider, page: Int) async throws -> [ImageSearchResult] {
        let offset = (page - 1) * 30
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrnamespace=6&gsrsearch=\(encoded)%20filetype:bitmap&gsrlimit=30&gsroffset=\(offset)&prop=imageinfo&iiprop=url|mime&iiurlwidth=700&format=json&origin=*") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("OneLyrics/2.0 (macOS Desktop App)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            return []
        }

        struct WikiResp: Codable {
            struct Query: Codable {
                struct Page: Codable {
                    let pageid: Int
                    let title: String?
                    let imageinfo: [ImageInfo]?
                    struct ImageInfo: Codable {
                        let url: String?
                        let thumburl: String?
                        let mime: String?
                    }
                }
                let pages: [String: Page]?
            }
            let query: Query?
        }

        guard let decoded = try? JSONDecoder().decode(WikiResp.self, from: data),
              let pages = decoded.query?.pages?.values else {
            return []
        }

        return pages.compactMap { p in
            guard let info = p.imageinfo?.first,
                  let full = info.url,
                  let thumb = info.thumburl ?? info.url else { return nil }

            // Extract a clean author / photo title from "File:..."
            var title = p.title ?? provider.rawValue
            if title.hasPrefix("File:") {
                title = String(title.dropFirst(5))
            }
            // Remove file extension
            if let dotIndex = title.lastIndex(of: ".") {
                title = String(title[..<dotIndex])
            }
            // Clean up trailing tags like (Unsplash) or (Pixabay)
            title = title.replacingOccurrences(of: "_\(provider.rawValue)", with: "")
                         .replacingOccurrences(of: " (\(provider.rawValue))", with: "")
                         .replacingOccurrences(of: "_", with: " ")
                         .trimmingCharacters(in: .whitespacesAndNewlines)

            let author = title.isEmpty ? provider.rawValue : title

            return ImageSearchResult(
                id: "\(provider.rawValue.lowercased())-\(p.pageid)",
                thumbURL: thumb,
                fullURL: full,
                authorName: author,
                provider: provider,
                color: nil
            )
        }
    }

    private func searchFlickr(query: String, provider: ImageProvider) async throws -> [ImageSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.flickr.com/services/feeds/photos_public.gne?tags=\(encoded)&format=json&nojsoncallback=1") else {
            return []
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        struct FlickrResp: Codable {
            struct Item: Codable {
                let title: String?
                let link: String?
                let media: Media?
                let author: String?
                struct Media: Codable {
                    let m: String?
                }
            }
            let items: [Item]?
        }

        guard let decoded = try? JSONDecoder().decode(FlickrResp.self, from: data),
              let items = decoded.items else {
            return []
        }

        return items.compactMap { item in
            guard let thumb = item.media?.m else { return nil }
            // Convert thumbnail (_m.jpg) to high-res (_b.jpg)
            let full = thumb.replacingOccurrences(of: "_m.jpg", with: "_b.jpg")
            
            // Clean author name from `nobody@flickr.com ("AuthorName")`
            var author = provider.rawValue
            if let rawAuthor = item.author,
               let start = rawAuthor.firstIndex(of: "\""),
               let end = rawAuthor.lastIndex(of: "\""),
               start < end {
                let authorSub = rawAuthor[rawAuthor.index(after: start)..<end]
                author = String(authorSub)
            } else if let title = item.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                author = title
            }

            return ImageSearchResult(
                id: "\(provider.rawValue.lowercased())-\(UUID().uuidString.prefix(8))",
                thumbURL: thumb,
                fullURL: full,
                authorName: author,
                provider: provider,
                color: nil
            )
        }
    }

    // MARK: - Download

    func downloadImage(_ result: ImageSearchResult) async throws -> URL {
        return try await downloadURL(result.fullURL)
    }

    func downloadURL(_ urlStr: String) async throws -> URL {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

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
