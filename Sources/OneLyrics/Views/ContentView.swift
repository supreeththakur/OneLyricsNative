import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    var onBack: () -> Void = {}
    @State private var showExportModal = false
    @State private var showSearchModal = false
    @State private var showYouTubePublish = false
    @State private var youtubeVideoURL: URL? = nil
    @State private var scheduleToYouTube: Bool = false
    @ObservedObject var exportManager = ExportManager.shared
    
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
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        store.pause()
                        onBack()
                    }) {
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
                        if !exportManager.jobs.isEmpty {
                            Button(action: { ExportManager.shared.launchExporterApp() }) {
                                HStack {
                                    if let active = exportManager.jobs.first(where: { $0.status == .exporting }) {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                            .frame(width: 12, height: 12)
                                        Text("\(Int(active.progress * 100))%")
                                    } else {
                                        Image(systemName: "film")
                                        Text("\(exportManager.jobs.count)")
                                    }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
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
                        
                        Button(action: { showYouTubePublish = true }) {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                Text("YouTube")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
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
                
                ExportModalView(isPresented: $showExportModal, onPublishToYouTube: { url, isScheduled in
                    self.showExportModal = false
                    self.youtubeVideoURL = url
                    self.scheduleToYouTube = isScheduled
                    self.showYouTubePublish = true
                })
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
            
            // YouTube Publish Modal Overlay
            if showYouTubePublish {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showYouTubePublish = false }
                    .zIndex(100)
                
                YouTubePublishView(isPresented: $showYouTubePublish, videoFileURL: youtubeVideoURL, initialSchedule: scheduleToYouTube)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .onDisappear {
            store.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addTextTemplateRequested)) { notification in
            if let text = notification.object as? String {
                let newBlock = LyricBlock(id: UUID(), text: text, startMs: store.currentTimeMs, endMs: store.currentTimeMs + 3000)
                store.state.lyrics.append(newBlock)
            }
        }
    }
}


