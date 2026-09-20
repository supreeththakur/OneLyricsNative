import SwiftUI

struct FetchLyricsModal: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: ProjectStore
    
    @State private var searchQuery: String = ""
    @State private var results: [LRCSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                Text("Auto Sync Lyrics")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.12))
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search song name or artist...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .onChange(of: searchQuery) { _ in
                        searchTask?.cancel()
                        if searchQuery.isEmpty {
                            results = []
                        } else {
                            searchTask = Task {
                                do {
                                    try await Task.sleep(nanoseconds: 500_000_000)
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run { performSearch() }
                                } catch {}
                            }
                        }
                    }
                    .onSubmit {
                        performSearch()
                    }
                
                if isSearching {
                    ProgressView().scaleEffect(0.6).padding(.leading, 8)
                }
            }
            .padding(10)
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .padding()
            
            // Results List
            if results.isEmpty && !isSearching && !searchQuery.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 8)
                    Text("No synced lyrics found.")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { result in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.trackName ?? "Unknown Track")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(result.artistName ?? "Unknown Artist")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if result.syncedLyrics != nil {
                                    Button(action: {
                                        applyLyrics(result: result)
                                    }) {
                                        HStack {
                                            Image(systemName: "wand.and.stars")
                                            Text("Apply Sync")
                                        }
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text("No Sync Data")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(12)
                            .background(Color(white: 0.15))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            // Try to pre-fill the search based on the project title
            if !store.state.title.isEmpty && !store.state.title.contains("New Project") {
                searchQuery = store.state.title
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        Task {
            do {
                let res = try await LRCLibManager.shared.search(query: searchQuery)
                // Filter only results that have synced lyrics
                let syncedResults = res.filter { $0.syncedLyrics != nil }
                
                DispatchQueue.main.async {
                    self.results = syncedResults
                    self.isSearching = false
                }
            } catch {
                print("LRC Search error: \(error)")
                DispatchQueue.main.async {
                    self.isSearching = false
                }
            }
        }
    }
    
    private func applyLyrics(result: LRCSearchResult) {
        guard let lrcText = result.syncedLyrics else { return }
        let blocks = LRCLibManager.shared.parseLRC(lrcText: lrcText)
        
        if !blocks.isEmpty {
            store.applySyncedLyrics(blocks)
            isPresented = false
        }
    }
}
