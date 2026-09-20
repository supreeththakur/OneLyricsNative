import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    var onBack: () -> Void = {}
    @State private var showExportModal = false
    @State private var showSearchModal = false
    
    var body: some View {
        ZStack {
            // Main App
            HSplitView {
                // Left Sidebar (Assets)
                AssetSidebar(showSearchModal: $showSearchModal)
                    .frame(width: 260)
                    
                // Main Content Area
                VStack(spacing: 0) {
                    // Player View
                    PlayerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    
                    // Timeline View
                    TimelineView()
                        .frame(height: 260)
                }
                .frame(minWidth: 400, maxWidth: .infinity)
                
                // Inspector (Settings)
                InspectorSidebar()
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 350)
                    .background(Color(white: 0.1))
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Projects")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(store.state.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button(action: { store.isShowingThumbnailMaker = true }) {
                            HStack {
                                Image(systemName: "photo.artframe")
                                Text("Thumbnail")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showExportModal = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Thumbnail Modal Overlay
            if store.isShowingThumbnailMaker {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { store.isShowingThumbnailMaker = false }
                    .zIndex(100)
                
                ThumbnailMakerModal(isPresented: $store.isShowingThumbnailMaker)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // Export Modal Overlay
            if showExportModal {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showExportModal = false }
                    .zIndex(100)
                
                ExportModalView(isPresented: $showExportModal)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // Search Modal Overlay
            if showSearchModal {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showSearchModal = false }
                    .zIndex(100)
                
                OnlineAudioSearchModal(isPresented: $showSearchModal)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // Lyrics Modal Overlay
            if store.isShowingLyricsFetch {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { store.isShowingLyricsFetch = false }
                    .zIndex(100)
                
                FetchLyricsModal(isPresented: $store.isShowingLyricsFetch)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // Background Modal Overlay
            if store.isShowingBackgroundFetch {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { store.isShowingBackgroundFetch = false }
                    .zIndex(100)
                
                FetchBackgroundModal(isPresented: $store.isShowingBackgroundFetch)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }
}


