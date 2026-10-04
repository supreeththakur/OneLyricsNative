import SwiftUI
import AppKit

struct ExportModalView: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    var onPublishToYouTube: ((URL, Bool) -> Void)? = nil
    @ObservedObject var settingsManager = ExportSettingsManager.shared
    @State private var outputPath = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Export Video")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            // Export Settings Form
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $settingsManager.settings.format) {
                        Text("MP4 (H.264)").tag("MP4")
                        Text("MOV (ProRes)").tag("MOV")
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resolution").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $settingsManager.settings.resolution) {
                        Text("1080p").tag("1080p")
                        Text("4K").tag("4K")
                        Text("Vertical (9:16)").tag("Vertical")
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality / Bitrate").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $settingsManager.settings.bitrate) {
                        Text("Standard").tag("Standard")
                        Text("High").tag("High")
                        Text("Lossless").tag("Lossless")
                    }
                    .pickerStyle(.segmented)
                }
                
                // Output Path
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Path").foregroundColor(.gray).font(.caption.weight(.semibold))
                    HStack {
                        Text(outputPath.isEmpty ? "~/Desktop/OneLyrics_Export" : outputPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        
                        Button("Browse") {
                            chooseOutputPath()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                Toggle("Generate YouTube Assets (Metadata & Thumbnail)", isOn: $settingsManager.settings.uploadToYouTube)
                    .font(.caption)
                    .foregroundColor(.white)
                    .tint(.red)
                    .padding(.top, 4)
                
                Spacer()
                
                // Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("Add to Queue") {
                        addToQueue()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .cornerRadius(8)
                    
                    Button("Export Now") {
                        addToQueue(priority: .high)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .font(.system(size: 14, weight: .bold))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(30)
        .frame(width: 480, height: 450)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .onAppear {
            let ext = settingsManager.settings.format == "MOV" ? "mov" : "mp4"
            let sanitizedName = store.state.title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
            var projectName = sanitizedName
            if projectName.isEmpty || projectName == "Untitled Project" || projectName == "New Project" {
                projectName = store.state.audioURL?.deletingPathExtension().lastPathComponent ?? "OneLyrics_Export"
            }
            outputPath = NSHomeDirectory() + "/Desktop/\(projectName).\(ext)"
        }
    }
    

    
    private func chooseOutputPath() {
        let panel = NSSavePanel()
        panel.title = "Save Exported Video"
        panel.allowedContentTypes = [.mpeg4Movie, .movie]
        let ext = settingsManager.settings.format == "MOV" ? "mov" : "mp4"
        let sanitizedName = store.state.title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        var projectName = sanitizedName
        if projectName.isEmpty || projectName == "Untitled Project" || projectName == "New Project" {
            projectName = store.state.audioURL?.deletingPathExtension().lastPathComponent ?? "OneLyrics_Export"
        }
        panel.nameFieldStringValue = "\(projectName).\(ext)"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func addToQueue(priority: ExportPriority = .normal) {
        let ext = settingsManager.settings.format == "MOV" ? "mov" : "mp4"
        var projectName = store.state.title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        
        if !outputPath.isEmpty {
            let url = URL(fileURLWithPath: outputPath)
            projectName = url.deletingPathExtension().lastPathComponent
        } else {
            if projectName.isEmpty || projectName == "Untitled Project" || projectName == "New Project" {
                projectName = store.state.audioURL?.deletingPathExtension().lastPathComponent ?? "OneLyrics_Export"
            }
        }
        
        let finalPath = outputPath.isEmpty ? NSHomeDirectory() + "/Desktop/\(projectName).\(ext)" : outputPath
        
        // Ensure extension matches format
        var url = URL(fileURLWithPath: finalPath)
        if url.pathExtension.lowercased() != ext {
            url = url.deletingPathExtension().appendingPathExtension(ext)
        }
        
        ExportManager.shared.addJob(
            projectName: projectName,
            state: store.state,
            durationMs: store.effectiveDuration,
            format: settingsManager.settings.format,
            resolution: settingsManager.settings.resolution,
            bitrate: settingsManager.settings.bitrate,
            outputURL: url,
            publishToYouTube: settingsManager.settings.uploadToYouTube,
            priority: priority
        )
        
        ExportManager.shared.launchExporterApp()
        
        isPresented = false
    }
    
}
