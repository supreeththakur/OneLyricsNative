import SwiftUI

struct AssetSidebar: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("PROJECT ASSETS")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)
            
            // Audio Section
            VStack(alignment: .leading) {
                Text("Audio").font(.subheadline).foregroundColor(.gray)
                Button(action: { importAudio() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(.gray.opacity(0.5))
                        if store.state.audioURL != nil {
                            VStack {
                                Image(systemName: "music.note")
                                Text("Audio Loaded").font(.caption)
                            }
                        } else {
                            VStack {
                                Image(systemName: "music.note")
                                Text("Import Audio").font(.caption)
                            }
                        }
                    }
                    .frame(height: 80)
                }
                .buttonStyle(.plain)
            }
            
            // Background Section
            VStack(alignment: .leading) {
                Text("Background").font(.subheadline).foregroundColor(.gray)
                Button(action: { importBackground() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(.gray.opacity(0.5))
                        if store.state.backgroundURL != nil {
                            VStack {
                                Image(systemName: "photo")
                                Text("Media Loaded").font(.caption)
                            }
                        } else {
                            VStack {
                                Image(systemName: "photo")
                                Text("Import Media").font(.caption)
                            }
                        }
                    }
                    .frame(height: 80)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(white: 0.12))
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

struct InspectorSidebar: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("INSPECTOR")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)
            
            VStack(alignment: .leading) {
                Text("Template").font(.subheadline).foregroundColor(.gray)
                Picker("", selection: $store.state.templateId) {
                    Text("Clean Music Channel").tag("CleanMusicChannel")
                    Text("Cinematic").tag("Cinematic")
                    Text("Neon").tag("Neon")
                }
                .labelsHidden()
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Typography").font(.subheadline).foregroundColor(.gray)
                
                HStack {
                    Text("Font Size")
                    Slider(value: $store.state.typography.fontSize, in: 24...120)
                }
                
                HStack {
                    Text("Glow Intensity")
                    Slider(value: $store.state.typography.glow, in: 0...30)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(white: 0.12))
    }
}
