import SwiftUI
import UniformTypeIdentifiers

struct AssetSidebar: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var showSearchModal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("PROJECT ASSETS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .tracking(1.5)
                .padding(.top, 10)
            
            // Audio Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio").font(.subheadline).foregroundColor(.gray)
                Button(action: { importAudio() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(store.state.audioURL != nil ? .green.opacity(0.5) : .gray.opacity(0.5))
                            .background(store.state.audioURL != nil ? Color.green.opacity(0.05) : Color.white.opacity(0.02))
                            .cornerRadius(12)
                        
                        if store.isConvertingAudio {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Converting to M4A...")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        } else if store.state.audioURL != nil {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("Audio Loaded")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Import Audio")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(height: 80)
                }
                .buttonStyle(.plain)
                .disabled(store.isConvertingAudio)
                
                Button(action: { showSearchModal = true }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Online")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Background Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Background").font(.subheadline).foregroundColor(.gray)
                Button(action: { importBackground() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(store.state.backgroundURL != nil ? .green.opacity(0.5) : .gray.opacity(0.5))
                            .background(store.state.backgroundURL != nil ? Color.green.opacity(0.05) : Color.white.opacity(0.02))
                            .cornerRadius(12)
                        
                        if store.state.backgroundURL != nil {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("Media Loaded")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Import Media")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(height: 80)
                    
                    Button(action: { store.isShowingBackgroundFetch = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search Online")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Lyrics Control Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Lyrics").font(.subheadline).foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    Button(action: { importLyrics() }) {
                        Text("Import File")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { store.clearLyrics() }) {
                        Text("Clear All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Global Sync Shift").font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("Adjust all timings").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                    }
                    
                    HStack(spacing: 8) {
                        ShiftButton(label: "-.5s") { store.shiftAllLyrics(by: -500) }
                        ShiftButton(label: "-.1s") { store.shiftAllLyrics(by: -100) }
                        ShiftButton(label: "+.1s") { store.shiftAllLyrics(by: 100) }
                        ShiftButton(label: "+.5s") { store.shiftAllLyrics(by: 500) }
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }
    
    private func importAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.importAndConvertAudio(url: url)
        }
    }
    
    private func importBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.setBackground(url: url)
        }
    }
    
    private func importLyrics() {
        let panel = NSOpenPanel()
        // Allow .srt, .lrc, and .txt
        panel.allowedContentTypes = [
            UTType.plainText, 
            UTType(filenameExtension: "srt"),
            UTType(filenameExtension: "lrc")
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                
                // Try parsing as SRT
                let blocks = SRTParser.parse(content: content)
                
                store.clearLyrics()
                
                if blocks.isEmpty {
                    // Fallback to basic text parsing if not a valid SRT
                    let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    var currentMs: Double = 0
                    for line in lines {
                        store.addLyric(LyricBlock(text: line, startMs: currentMs, endMs: currentMs + 3000))
                        currentMs += 3500
                    }
                } else {
                    for block in blocks {
                        store.addLyric(block)
                    }
                }
            } catch {
                print("Failed to read lyrics: \(error)")
            }
        }
    }
}

struct ShiftButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(label.hasPrefix("-") ? .red : .green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

enum InspectorTab: String, CaseIterable {
    case text = "Text"
    case bg = "BG"
    case audio = "Audio"
}

struct InspectorSidebar: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject var fontManager = FontManager.shared
    @State private var showFontManager = false
    @State private var showTemplateManager = false
    @State private var showingSaveTemplateAlert = false
    @State private var newTemplateName = ""
    
    @State private var selectedTab: InspectorTab = .text
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("INSPECTOR")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                    .padding(.top, 10)
                
                Picker("", selection: $selectedTab) {
                    ForEach(InspectorTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                if selectedTab == .audio {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Volume: \(Int(store.state.mediaConfig.volume * 100))%").font(.caption2).foregroundColor(.gray)
                            Slider(value: Binding(
                                get: { Double(store.state.mediaConfig.volume) },
                                set: { store.state.mediaConfig.volume = Float($0) }
                            ), in: 0.0...2.0)
                            .tint(.purple)
                        }
                    }
                }
                
                if selectedTab == .bg {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scale (Crop): \(String(format: "%.2f", store.state.mediaConfig.cropScale))x").font(.caption2).foregroundColor(.gray)
                            Slider(value: $store.state.mediaConfig.cropScale, in: 0.5...3.0)
                                .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Offset X: \(Int(store.state.mediaConfig.cropOffsetX))").font(.caption2).foregroundColor(.gray)
                                Spacer()
                                Button("Reset") { store.state.mediaConfig.cropOffsetX = 0 }
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.blue)
                                    .buttonStyle(.plain)
                            }
                            Slider(value: $store.state.mediaConfig.cropOffsetX, in: -500...500)
                                .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Offset Y: \(Int(store.state.mediaConfig.cropOffsetY))").font(.caption2).foregroundColor(.gray)
                                Spacer()
                                Button("Reset") { store.state.mediaConfig.cropOffsetY = 0 }
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.blue)
                                    .buttonStyle(.plain)
                            }
                            Slider(value: $store.state.mediaConfig.cropOffsetY, in: -500...500)
                                .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brightness: \(String(format: "%.2f", store.state.mediaConfig.brightness))").font(.caption2).foregroundColor(.gray)
                            Slider(value: $store.state.mediaConfig.brightness, in: -1.0...1.0)
                                .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Contrast: \(String(format: "%.2f", store.state.mediaConfig.contrast))").font(.caption2).foregroundColor(.gray)
                            Slider(value: $store.state.mediaConfig.contrast, in: 0.0...3.0)
                                .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Saturation: \(String(format: "%.2f", store.state.mediaConfig.saturation))").font(.caption2).foregroundColor(.gray)
                            Slider(value: $store.state.mediaConfig.saturation, in: 0.0...3.0)
                                .tint(.blue)
                        }
                    }
                }
                
                if selectedTab == .text {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // 2. Templates
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Template").font(.caption).foregroundColor(.gray)
                                Spacer()
                                Button("Manage") { showTemplateManager = true }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue)
                                    .buttonStyle(.plain)
                                Button("Save As...") { 
                                    newTemplateName = ""
                                    showingSaveTemplateAlert = true
                                }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.purple)
                                    .buttonStyle(.plain)
                            }
                            Picker("", selection: Binding(
                                get: { store.state.templateId },
                                set: { newId in 
                                    store.state.templateId = newId
                                    TemplateManager.applyTemplate(newId, to: &store.state.typography)
                                }
                            )) {
                                ForEach(TemplateManager.templates, id: \.self) { t in
                                    Text(t).tag(t)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        
                        Divider().background(Color.white.opacity(0.05)).padding(.vertical, 4)
                        
                        // 3. Typography
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Typography Style").font(.caption).foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Font Family").font(.caption2).foregroundColor(.gray)
                                    Spacer()
                                    Button("Manage Fonts") { showFontManager = true }
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                        .buttonStyle(.plain)
                                }
                                Picker("", selection: $store.state.typography.fontFamily) {
                                    ForEach(fontManager.availableFonts, id: \.self) { fontName in
                                        Text(fontName).tag(fontName)
                                    }
                                }
                                .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alignment").font(.caption2).foregroundColor(.gray)
                                Picker("", selection: $store.state.typography.alignment) {
                                    ForEach(TextAlignmentStyle.allCases, id: \.self) { alignment in
                                        Text(alignment.rawValue).tag(alignment)
                                    }
                                }
                                .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Animation").font(.caption2).foregroundColor(.gray)
                                Picker("", selection: $store.state.typography.animationStyle) {
                                    ForEach(AnimationStyle.allCases, id: \.self) { anim in
                                        Text(anim.rawValue).tag(anim)
                                    }
                                }
                                .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Color").font(.caption2).foregroundColor(.gray)
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: store.state.typography.color) },
                                    set: { newColor in 
                                        if let hex = newColor.toHex() {
                                            store.state.typography.color = "#\(hex)"
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Font Size: \(Int(store.state.typography.fontSize))px").font(.caption2).foregroundColor(.gray)
                                Slider(value: $store.state.typography.fontSize, in: 40...400)
                                    .tint(.purple)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Edge Padding: \(Int(store.state.typography.edgePadding))px").font(.caption2).foregroundColor(.gray)
                                Slider(value: $store.state.typography.edgePadding, in: 0...400)
                                    .tint(.purple)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Glow Intensity: \(Int(store.state.typography.glow))px").font(.caption2).foregroundColor(.gray)
                                Slider(value: $store.state.typography.glow, in: 0...100)
                                    .tint(.purple)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Glow Color").font(.caption2).foregroundColor(.gray)
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: store.state.typography.glowColor ?? "#000000") },
                                    set: { newColor in 
                                        if let hex = newColor.toHex() {
                                            store.state.typography.glowColor = "#\(hex)"
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Enable Stroke", isOn: $store.state.typography.hasStroke)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .tint(.purple)
                            }
                            
                            if store.state.typography.hasStroke {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stroke Color").font(.caption2).foregroundColor(.gray)
                                    ColorPicker("", selection: Binding(
                                        get: { Color(hex: store.state.typography.strokeColor) },
                                        set: { newColor in 
                                            if let hex = newColor.toHex() {
                                                store.state.typography.strokeColor = "#\(hex)"
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stroke Width: \(String(format: "%.1f", store.state.typography.strokeWidth))px").font(.caption2).foregroundColor(.gray)
                                    Slider(value: $store.state.typography.strokeWidth, in: 0.5...15.0)
                                        .tint(.purple)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .popover(isPresented: $showTemplateManager) {
            TemplateManagerView()
        }
        .popover(isPresented: $showFontManager) {
            FontManagerView()
        }
        .alert("Save Custom Template", isPresented: $showingSaveTemplateAlert) {
            TextField("Template Name", text: $newTemplateName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let name = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    TemplateManager.saveTemplate(name: name, config: store.state.typography)
                    store.state.templateId = name // Switch to it
                }
            }
        } message: {
            Text("Enter a name for your custom typography template.")
        }
    }
}

extension Color {
    func toHex() -> String? {
        let nsColor = NSColor(self)
        // Convert to sRGB to ensure we have RGB components (macOS color picker can return CMYK, Gray, etc.)
        guard let converted = nsColor.usingColorSpace(.sRGB) else { return nil }
        
        let r = Int(max(0, min(1, converted.redComponent)) * 255)
        let g = Int(max(0, min(1, converted.greenComponent)) * 255)
        let b = Int(max(0, min(1, converted.blueComponent)) * 255)
        
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
