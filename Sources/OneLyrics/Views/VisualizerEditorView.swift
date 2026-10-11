import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct VisualizerEditorView: View {
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
                
                // Visualizer Inspector (Settings)
                VisualizerInspectorSidebar()
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
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.purple)
                        Text(store.state.title + " (Visualizer)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        if !exportManager.jobs.isEmpty {
                            Button(action: { ExportManager.shared.launchExporterApp() }) {
                                HStack {
                                    if exportManager.jobs.contains(where: { $0.status == .exporting }) {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                            .frame(width: 12, height: 12)
                                        Text("Exporting...")
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
            
            // Cover Image Search Modal Overlay
            if store.isShowingCoverSearch {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { store.isShowingCoverSearch = false }
                    .zIndex(100)
                
                OnlineCoverSearchModal(isPresented: $store.isShowingCoverSearch)
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
    }
}

struct VisualizerInspectorSidebar: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("VISUALIZER SETTINGS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                    .padding(.top, 10)
                
                // Visualizer Type & Preset
                VStack(alignment: .leading, spacing: 12) {
                    Text("Style")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Picker("Type", selection: Binding(
                        get: { store.state.visualizerConfig.type },
                        set: { store.state.visualizerConfig.type = $0; store.objectWillChange.send() }
                    )) {
                        ForEach(VisualizerType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Preset", selection: Binding(
                        get: { store.state.visualizerConfig.preset },
                        set: { store.state.visualizerConfig.preset = $0; store.objectWillChange.send() }
                    )) {
                        ForEach(VisualizerPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Colors & Aesthetics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aesthetics")
                        .font(.system(size: 13, weight: .semibold))
                    
                    // Note: Ideally use ColorPicker here, but string hex is fine for now
                    HStack {
                        Text("Color 1")
                            .font(.caption)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: store.state.visualizerConfig.color1) },
                            set: { store.state.visualizerConfig.color1 = $0.toHex() ?? "#ffffff"; store.objectWillChange.send() }
                        ))
                    }
                    
                    HStack {
                        Text("Color 2")
                            .font(.caption)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: store.state.visualizerConfig.color2) },
                            set: { store.state.visualizerConfig.color2 = $0.toHex() ?? "#ff00ff"; store.objectWillChange.send() }
                        ))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Glow Intensity: \(String(format: "%.1f", store.state.visualizerConfig.glowIntensity))")
                            .font(.caption)
                        Slider(value: Binding(
                            get: { store.state.visualizerConfig.glowIntensity },
                            set: { store.state.visualizerConfig.glowIntensity = $0; store.objectWillChange.send() }
                        ), in: 0...5)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Particles & Motion
                VStack(alignment: .leading, spacing: 12) {
                    Text("Effects")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Toggle("Enable Particles", isOn: Binding(
                        get: { store.state.visualizerConfig.particlesEnabled },
                        set: { store.state.visualizerConfig.particlesEnabled = $0; store.objectWillChange.send() }
                    ))
                    
                    if store.state.visualizerConfig.particlesEnabled {
                        VStack(alignment: .leading) {
                            Text("Particle Count: \(store.state.visualizerConfig.particleCount)")
                                .font(.caption)
                            Slider(value: Binding(
                                get: { Double(store.state.visualizerConfig.particleCount) },
                                set: { store.state.visualizerConfig.particleCount = Int($0); store.objectWillChange.send() }
                            ), in: 10...500)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Motion Intensity: \(String(format: "%.1f", store.state.visualizerConfig.motionIntensity))")
                            .font(.caption)
                        Slider(value: Binding(
                            get: { store.state.visualizerConfig.motionIntensity },
                            set: { store.state.visualizerConfig.motionIntensity = $0; store.objectWillChange.send() }
                        ), in: 0...3)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Cover Art
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cover Art")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Button(action: { store.isShowingCoverSearch = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 12))
                            Text("Search YouTube Cover")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.18))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    if store.state.coverImageURL != nil {
                        Button(action: {
                            store.state.coverImageURL = nil
                            store.objectWillChange.send()
                        }) {
                            Text("Reset Cover to Original")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Text Overlay
                VStack(alignment: .leading, spacing: 12) {
                    Text("Text Overlay")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Toggle("Show Title", isOn: Binding(
                        get: { store.state.visualizerConfig.textOverlay.showTitle },
                        set: { store.state.visualizerConfig.textOverlay.showTitle = $0; store.objectWillChange.send() }
                    ))
                    if store.state.visualizerConfig.textOverlay.showTitle {
                        TextField("Song Title", text: Binding(
                            get: { store.state.visualizerConfig.textOverlay.title },
                            set: { store.state.visualizerConfig.textOverlay.title = $0; store.objectWillChange.send() }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Toggle("Show Artist", isOn: Binding(
                        get: { store.state.visualizerConfig.textOverlay.showArtist },
                        set: { store.state.visualizerConfig.textOverlay.showArtist = $0; store.objectWillChange.send() }
                    ))
                    if store.state.visualizerConfig.textOverlay.showArtist {
                        TextField("Artist Name", text: Binding(
                            get: { store.state.visualizerConfig.textOverlay.artist },
                            set: { store.state.visualizerConfig.textOverlay.artist = $0; store.objectWillChange.send() }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Font Family")
                            .font(.caption)
                        Picker("", selection: Binding(
                            get: { store.state.typography.fontFamily },
                            set: { store.state.typography.fontFamily = $0; store.objectWillChange.send() }
                        )) {
                            ForEach(FontManager.shared.availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
    }
}
