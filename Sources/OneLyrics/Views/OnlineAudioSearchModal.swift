import SwiftUI
import AVFoundation

struct OnlineAudioSearchModal: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    
    @State private var searchQuery: String = ""
    @State private var results: [YTResult] = []
    @State private var isSearching = false
    @State private var downloadingId: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    @StateObject private var ytdl = YTDLManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Search Online Audio")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(white: 0.12))
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search YouTube (e.g. Blinding Lights instrumental)", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        searchTask?.cancel()
                        performSearch()
                    }
                    .onChange(of: searchQuery) { _ in
                        searchTask?.cancel()
                        if searchQuery.isEmpty {
                            results = []
                            return
                        }
                        searchTask = Task {
                            do {
                                try await Task.sleep(nanoseconds: 400_000_000)
                                guard !Task.isCancelled else { return }
                                await MainActor.run { performSearch() }
                            } catch {
                                // Cancelled
                            }
                        }
                    }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Results List
            if ytdl.isDownloadingEngine {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Downloading Search Engine (One-time setup)...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else if results.isEmpty && !isSearching {
                VStack {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 8)
                    Text("Search for songs, instrumentals, or sound effects")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { result in
                            HStack(spacing: 12) {
                                // Thumbnail
                                let thumbUrlStr = "https://i.ytimg.com/vi/\(result.id)/hqdefault.jpg"
                                if let thumbUrl = URL(string: thumbUrlStr) {
                                    AsyncImage(url: thumbUrl) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().aspectRatio(16/9, contentMode: .fit)
                                        default:
                                            Rectangle().fill(Color(white: 0.2))
                                                .aspectRatio(16/9, contentMode: .fit)
                                        }
                                    }
                                    .frame(width: 120, height: 67)
                                    .cornerRadius(6)
                                } else {
                                    Rectangle().fill(Color(white: 0.2))
                                        .frame(width: 120, height: 67)
                                        .cornerRadius(6)
                                }
                                
                                // Info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                    
                                    if let duration = result.duration {
                                        Text(formatDuration(duration))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                // Download Button
                                if downloadingId == result.id {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 10)
                                } else {
                                    Button(action: {
                                        downloadAndUse(result: result)
                                    }) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(downloadingId != nil)
                                }
                            }
                            .padding(12)
                            .background(Color(white: 0.15))
                            .cornerRadius(8)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        Task {
            do {
                let res = try await ytdl.search(query: searchQuery)
                DispatchQueue.main.async {
                    self.results = res
                    self.isSearching = false
                }
            } catch {
                print("Search error: \(error)")
                DispatchQueue.main.async {
                    self.isSearching = false
                }
            }
        }
    }
    
    private func downloadAndUse(result: YTResult) {
        downloadingId = result.id
        
        Task {
            do {
                let url = try await ytdl.downloadAudio(id: result.id)
                DispatchQueue.main.async {
                    // Force convert to fix YouTube DASH m4a double-duration metadata bug
                    store.importAndConvertAudio(url: url, forceConvert: true)
                    self.downloadingId = nil
                    self.isPresented = false
                }
            } catch {
                print("Download error: \(error)")
                DispatchQueue.main.async {
                    self.downloadingId = nil
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
