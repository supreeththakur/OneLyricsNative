import SwiftUI

struct AssetSidebar: View {
    @EnvironmentObject var store: ProjectStore
    
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
                        
                        if store.state.audioURL != nil {
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
                }
                .buttonStyle(.plain)
            }
            
            // Lyrics Control Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Lyrics").font(.subheadline).foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    Button(action: { /* Import Lyrics */ }) {
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
                
                // Global Sync Shift
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Global Sync Shift").font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("Adjust all timings").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                    }
                    
                    HStack(spacing: 8) {
                        ShiftButton(label: "-500", action: { store.shiftAllLyrics(by: -500) })
                        ShiftButton(label: "-100", action: { store.shiftAllLyrics(by: -100) })
                        ShiftButton(label: "+100", action: { store.shiftAllLyrics(by: 100) })
                        ShiftButton(label: "+500", action: { store.shiftAllLyrics(by: 500) })
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08)) // Sleek dark sidebar
    }
    
    private func importAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.setAudio(url: url)
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

struct InspectorSidebar: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("INSPECTOR")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .tracking(1.5)
                .padding(.top, 10)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Template").font(.subheadline).foregroundColor(.gray)
                Picker("", selection: $store.state.templateId) {
                    Text("Clean Music Channel").tag("CleanMusicChannel")
                    Text("Cinematic").tag("Cinematic")
                    Text("Neon").tag("Neon")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Typography").font(.subheadline).foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font Size: \(Int(store.state.typography.fontSize))px").font(.caption).foregroundColor(.gray)
                    Slider(value: $store.state.typography.fontSize, in: 24...120)
                        .tint(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Glow Intensity: \(Int(store.state.typography.glow))px").font(.caption).foregroundColor(.gray)
                    Slider(value: $store.state.typography.glow, in: 0...30)
                        .tint(.purple)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }
}
