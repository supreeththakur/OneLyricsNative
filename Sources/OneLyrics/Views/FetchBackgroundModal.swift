import SwiftUI

struct FetchBackgroundModal: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: ProjectStore
    
    @State private var isSearching = false
    @State private var downloadingId: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var currentPage: Int = 1
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreResults: Bool = true
    @State private var errorMessage: String? = nil
    
    let columns = [GridItem(.adaptive(minimum: 148), spacing: 12)]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── Header ───────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                Text("Search Backgrounds")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.12))
            
            // ── Provider Picker ──────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(ImageProvider.allCases) { provider in
                    providerTab(provider)
                }
            }
            .background(Color(white: 0.10))
            
            // ── Search Bar ───────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 13))
                TextField("Search \(store.bgProvider.rawValue)...", text: $store.bgSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .onChange(of: store.bgSearchQuery) { _ in
                        triggerSearch()
                    }
                    .onSubmit { performSearch(isNewSearch: true) }
                
                if isSearching && !isLoadingMore {
                    ProgressView().scaleEffect(0.6)
                }
                if !store.bgSearchQuery.isEmpty {
                    Button { store.bgSearchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.7))
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // ── Error Banner ─────────────────────────────────────────
            if let err = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button { errorMessage = nil } label: {
                        Image(systemName: "xmark").font(.caption).foregroundColor(.gray)
                    }.buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            
            // ── Results Grid ─────────────────────────────────────────
            if store.bgSearchResults.isEmpty && !isSearching && !store.bgSearchQuery.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No photos found on \(store.bgProvider.rawValue).")
                        .foregroundColor(.gray)
                        .font(.callout)
                    Spacer()
                }
            } else if store.bgSearchResults.isEmpty && !isSearching {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Search for backgrounds on \(store.bgProvider.rawValue)")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.callout)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.bgSearchResults) { result in
                            resultCard(result)
                        }
                        
                        // Infinite scroll trigger
                        if hasMoreResults && !store.bgSearchResults.isEmpty {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    if !isLoadingMore { performSearch(isNewSearch: false) }
                                }
                            if isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(width: 720, height: 520)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .shadow(radius: 24)
        .onChange(of: store.bgProvider) { _ in
            // Clear results and re-search when provider changes
            store.bgSearchResults = []
            errorMessage = nil
            hasMoreResults = true
            if !store.bgSearchQuery.isEmpty {
                performSearch(isNewSearch: true)
            }
        }
    }
    
    // MARK: - Provider Tab Button
    
    @ViewBuilder
    private func providerTab(_ provider: ImageProvider) -> some View {
        let isSelected = store.bgProvider == provider
        Button {
            store.bgProvider = provider
        } label: {
            HStack(spacing: 5) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(provider.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.blue.opacity(0.25)
                    : Color.clear
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .blue : .clear),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
    
    // MARK: - Result Card
    
    @ViewBuilder
    private func resultCard(_ result: ImageSearchResult) -> some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: result.thumbURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color(white: 0.18))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo.slash")
                                .foregroundColor(.gray.opacity(0.5))
                        )
                default:
                    Rectangle()
                        .fill(Color(white: 0.18))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(ProgressView().scaleEffect(0.5))
                }
            }
            .frame(height: 88)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Gradient + author + download icon
            LinearGradient(
                colors: [.black.opacity(0.75), .clear],
                startPoint: .bottom, endPoint: .top
            )
            .frame(height: 32)
            .cornerRadius(8)
            
            HStack {
                Text(result.authorName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                if downloadingId == result.id {
                    ProgressView().scaleEffect(0.45).tint(.white)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .scaleEffect(downloadingId == result.id ? 0.96 : 1.0)
        .animation(.spring(response: 0.2), value: downloadingId == result.id)
        .onTapGesture { downloadAndApply(result: result) }
        .disabled(downloadingId != nil)
    }
    
    // MARK: - Search Logic
    
    private func triggerSearch() {
        searchTask?.cancel()
        if store.bgSearchQuery.isEmpty {
            store.bgSearchResults = []
            errorMessage = nil
        } else {
            searchTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 450_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { performSearch(isNewSearch: true) }
                } catch {}
            }
        }
    }
    
    private func performSearch(isNewSearch: Bool) {
        guard !store.bgSearchQuery.isEmpty else { return }
        
        if isNewSearch {
            isSearching = true
            currentPage = 1
            hasMoreResults = true
            store.bgSearchResults = []
            errorMessage = nil
        } else {
            isLoadingMore = true
            currentPage += 1
        }
        
        let query    = store.bgSearchQuery
        let page     = currentPage
        let provider = store.bgProvider
        
        Task {
            do {
                let results = try await ImageSearchManager.shared.search(query: query, provider: provider, page: page)
                await MainActor.run {
                    if isNewSearch {
                        store.bgSearchResults = results
                    } else {
                        store.bgSearchResults.append(contentsOf: results)
                    }
                    hasMoreResults = !results.isEmpty
                    isSearching    = false
                    isLoadingMore  = false
                }
            } catch {
                await MainActor.run {
                    errorMessage  = "Failed to load: \(error.localizedDescription)"
                    isSearching   = false
                    isLoadingMore = false
                }
            }
        }
    }
    
    private func downloadAndApply(result: ImageSearchResult) {
        downloadingId = result.id
        Task {
            do {
                let url = try await ImageSearchManager.shared.downloadImage(result)
                await MainActor.run {
                    store.setBackground(url: url)
                    downloadingId = nil
                    isPresented   = false
                }
            } catch {
                await MainActor.run {
                    errorMessage  = "Download failed: \(error.localizedDescription)"
                    downloadingId = nil
                }
            }
        }
    }
}
