import SwiftUI

struct FetchBackgroundModal: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: ProjectStore
    
    @State private var searchQuery: String = ""
    @State private var results: [UnsplashResult] = []
    @State private var isSearching = false
    @State private var downloadingId: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    @State private var currentPage: Int = 1
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreResults: Bool = true
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("Search Backgrounds (Unsplash)")
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
                TextField("Search nature, neon, abstract...", text: $searchQuery)
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
                                    await MainActor.run { performSearch(isNewSearch: true) }
                                } catch {}
                            }
                        }
                    }
                    .onSubmit {
                        performSearch(isNewSearch: true)
                    }
                
                if isSearching && !isLoadingMore {
                    ProgressView().scaleEffect(0.6).padding(.leading, 8)
                }
            }
            .padding(10)
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .padding()
            
            // Results Grid
            if results.isEmpty && !isSearching && !searchQuery.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 8)
                    Text("No photos found.")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(results) { result in
                            ZStack(alignment: .bottomTrailing) {
                                // Thumbnail Image
                                AsyncImage(url: URL(string: result.urls?.thumb ?? "")) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(16/9, contentMode: .fill)
                                    default:
                                        Rectangle().fill(Color(white: 0.2))
                                            .aspectRatio(16/9, contentMode: .fit)
                                    }
                                }
                                .frame(height: 90)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                
                                // Overlay Gradient for author name
                                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top)
                                    .frame(height: 30)
                                
                                HStack {
                                    Text("By \(result.user?.name ?? "Unknown")")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                    Spacer()
                                    if downloadingId == result.id {
                                        ProgressView().scaleEffect(0.5)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if result.urls?.regular != nil {
                                    downloadAndApply(result: result)
                                }
                            }
                            .disabled(downloadingId != nil)
                        }
                        
                        if hasMoreResults && !results.isEmpty {
                            Color.clear
                                .frame(height: 20)
                                .onAppear {
                                    if !isLoadingMore {
                                        performSearch(isNewSearch: false)
                                    }
                                }
                            
                            if isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .frame(width: 700, height: 500)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
    
    private func performSearch(isNewSearch: Bool) {
        guard !searchQuery.isEmpty else { return }
        
        if isNewSearch {
            isSearching = true
            currentPage = 1
            hasMoreResults = true
            results.removeAll()
        } else {
            isLoadingMore = true
            currentPage += 1
        }
        
        let queryToSearch = searchQuery
        let pageToSearch = currentPage
        
        Task {
            do {
                let res = try await UnsplashManager.shared.search(query: queryToSearch, page: pageToSearch)
                DispatchQueue.main.async {
                    if isNewSearch {
                        self.results = res
                    } else {
                        self.results.append(contentsOf: res)
                    }
                    if res.isEmpty {
                        self.hasMoreResults = false
                    }
                    self.isSearching = false
                    self.isLoadingMore = false
                }
            } catch {
                print("Unsplash Search error: \(error)")
                DispatchQueue.main.async {
                    self.isSearching = false
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    private func downloadAndApply(result: UnsplashResult) {
        guard let urlStr = result.urls?.regular else { return }
        downloadingId = result.id
        
        Task {
            do {
                let url = try await UnsplashManager.shared.downloadImage(urlStr: urlStr)
                DispatchQueue.main.async {
                    store.setBackground(url: url)
                    self.downloadingId = nil
                    self.isPresented = false
                }
            } catch {
                print("Unsplash Download error: \(error)")
                DispatchQueue.main.async {
                    self.downloadingId = nil
                }
            }
        }
    }
}
