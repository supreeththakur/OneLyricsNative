import SwiftUI
import AVFoundation

struct OnlineCoverSearchModal: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    
    @State private var isSearching = false
    @State private var downloadingId: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    @StateObject private var ytdl = YTDLManager.shared
    
    let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search YouTube Cover Art")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Search any song to fetch & set its official cover/thumbnail")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color(white: 0.12))
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search YouTube (e.g. Song name, Artist, Movie track)...", text: $store.coverSearchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onSubmit {
                        searchTask?.cancel()
                        performSearch()
                    }
                    .onChange(of: store.coverSearchQuery) { _ in
                        searchTask?.cancel()
                        if store.coverSearchQuery.isEmpty {
                            store.coverSearchResults = []
                            return
                        }
                        searchTask = Task {
                            do {
                                try await Task.sleep(nanoseconds: 350_000_000)
                                guard !Task.isCancelled else { return }
                                await MainActor.run { performSearch() }
                            } catch {
                                // Cancelled
                            }
                        }
                    }
                
                if !store.coverSearchQuery.isEmpty {
                    Button(action: {
                        store.coverSearchQuery = ""
                        store.coverSearchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(white: 0.16))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 6)
            
            // Quick Suggestion Chips if audio is loaded
            let currentTitle = store.state.visualizerConfig.textOverlay.title
            if !currentTitle.isEmpty && store.coverSearchQuery.isEmpty {
                HStack(spacing: 8) {
                    Text("Suggestion:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        store.coverSearchQuery = currentTitle
                        performSearch()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text(currentTitle)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            
            // Content Body
            if ytdl.isDownloadingEngine {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Setting up search engine...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else if store.coverSearchResults.isEmpty && !isSearching {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Search for a song or artist on YouTube")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Text("High-resolution cover art will be automatically fetched & linked")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                    Spacer()
                }
                .padding(.bottom, 20)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.coverSearchResults) { result in
                            CoverResultCard(
                                result: result,
                                isDownloading: downloadingId == result.id,
                                onSelect: {
                                    downloadAndApplyCover(result: result)
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 680, height: 530)
        .background(Color(white: 0.09))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.7), radius: 25)
        .onAppear {
            if store.coverSearchQuery.isEmpty {
                if !store.state.visualizerConfig.textOverlay.title.isEmpty {
                    store.coverSearchQuery = store.state.visualizerConfig.textOverlay.title
                    performSearch()
                } else if let audioUrl = store.state.audioURL {
                    let baseName = audioUrl.deletingPathExtension().lastPathComponent
                    store.coverSearchQuery = baseName
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        let q = store.coverSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true
        
        Task {
            do {
                let res = try await ytdl.search(query: q)
                await MainActor.run {
                    self.store.coverSearchResults = res
                    self.isSearching = false
                }
            } catch {
                print("Cover search error: \(error)")
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }
    
    private func downloadAndApplyCover(result: YTResult) {
        downloadingId = result.id
        
        Task {
            do {
                // High-resolution YouTube thumbnail URLs
                let maxResUrl = "https://i.ytimg.com/vi/\(result.id)/maxresdefault.jpg"
                let hqResUrl = "https://i.ytimg.com/vi/\(result.id)/hqdefault.jpg"
                
                var chosenData: Data? = nil
                
                // Try MaxRes
                if let url = URL(string: maxResUrl),
                   let (data, resp) = try? await URLSession.shared.data(from: url),
                   let http = resp as? HTTPURLResponse, http.statusCode == 200, data.count > 10000 {
                    chosenData = data
                }
                
                // Fallback to HQ
                if chosenData == nil {
                    if let url = URL(string: hqResUrl),
                       let (data, resp) = try? await URLSession.shared.data(from: url),
                       let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        chosenData = data
                    }
                }
                
                guard let imageData = chosenData, let _ = NSImage(data: imageData) else {
                    throw URLError(.cannotDecodeContentData)
                }
                
                let fileManager = FileManager.default
                let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let appDir = appSupport.appendingPathComponent("OneLyricsNative", isDirectory: true)
                if !fileManager.fileExists(atPath: appDir.path) {
                    try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
                }
                
                let dest = appDir.appendingPathComponent("cover_\(result.id).jpg")
                try imageData.write(to: dest)
                
                await MainActor.run {
                    // Set cover image in store
                    self.store.setCoverImage(url: dest)
                    
                    // Auto-fill title if empty
                    if self.store.state.visualizerConfig.textOverlay.title.isEmpty {
                        self.store.state.visualizerConfig.textOverlay.title = cleanTitle(result.title)
                    }
                    
                    self.downloadingId = nil
                    self.isPresented = false
                }
            } catch {
                print("Failed to download cover image: \(error)")
                await MainActor.run {
                    self.downloadingId = nil
                }
            }
        }
    }
    
    private func cleanTitle(_ title: String) -> String {
        var t = title
        // Remove common YouTube suffixes
        let removals = [
            "\\(Official Video\\)", "\\[Official Video\\]",
            "\\(Official Music Video\\)", "\\[Official Music Video\\]",
            "\\(Official Audio\\)", "\\[Official Audio\\]",
            "\\(Lyrics\\)", "\\[Lyrics\\]",
            "\\(Lyric Video\\)", "\\[Lyric Video\\]",
            "\\(Visualizer\\)", "\\[Visualizer\\]",
            "\\(4K\\)", "\\[4K\\]", "\\(HD\\)", "\\[HD\\]"
        ]
        for pattern in removals {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                t = regex.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: t.count), withTemplate: "")
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CoverResultCard: View {
    let result: YTResult
    let isDownloading: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Thumbnail
                    let thumbUrlStr = "https://i.ytimg.com/vi/\(result.id)/hqdefault.jpg"
                    if let thumbUrl = URL(string: thumbUrlStr) {
                        AsyncImage(url: thumbUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(Color(white: 0.18))
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .overlay(
                                        ProgressView().scaleEffect(0.6)
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipped()
                        .cornerRadius(8)
                    }
                    
                    // Duration badge
                    if let duration = result.duration {
                        Text(formatDuration(duration))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .padding(6)
                    }
                    
                    // Selection / Download Overlay
                    if isDownloading {
                        Color.black.opacity(0.6)
                            .cornerRadius(8)
                            .overlay(
                                VStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Setting...")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            )
                    }
                }
                
                // Title
                Text(result.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Select button
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Use as Cover")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(isHovered ? .white : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHovered ? Color.red : Color.red.opacity(0.15))
                    .cornerRadius(6)
                }
            }
            .padding(10)
            .background(isHovered ? Color(white: 0.18) : Color(white: 0.13))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? Color.red.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .disabled(isDownloading)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
