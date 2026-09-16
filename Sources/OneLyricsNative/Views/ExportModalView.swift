import SwiftUI
import AppKit

struct ExportModalView: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    @StateObject private var exporter = VideoExporter()
    
    @State private var selectedFormat = "MP4"
    @State private var selectedResolution = "1080p"
    @State private var selectedBitrate = "High"
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
            
            if exporter.isExporting {
                // Progress View
                VStack(spacing: 16) {
                    Spacer()
                    
                    Text("Rendering Video...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ProgressView(value: exporter.progress)
                        .progressViewStyle(.linear)
                        .tint(.green)
                    
                    Text("\(Int(exporter.progress * 100))%")
                        .font(.system(.title, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text("Please wait, this may take a few minutes...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
            } else if let exportedURL = exporter.exportedURL {
                // Success View
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Export Complete!")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    
                    Text(exportedURL.path)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        Button("Show in Finder") {
                            NSWorkspace.shared.selectFile(exportedURL.path, inFileViewerRootedAtPath: "")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button("Done") {
                            isPresented = false
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            } else {
                // Settings View
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $selectedFormat) {
                        Text("MP4 (H.264)").tag("MP4")
                        Text("MOV (ProRes)").tag("MOV")
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resolution").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $selectedResolution) {
                        Text("1080p").tag("1080p")
                        Text("4K").tag("4K")
                        Text("Vertical (9:16)").tag("Vertical")
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality / Bitrate").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $selectedBitrate) {
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
                
                if let error = exporter.exportError {
                    Text("⚠️ \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                
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
                    
                    Button("Start Export") {
                        startExport()
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
        }
        .padding(30)
        .frame(width: 480, height: 450)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .onAppear {
            let ext = selectedFormat == "MOV" ? "mov" : "mp4"
            outputPath = NSHomeDirectory() + "/Desktop/OneLyrics_Export.\(ext)"
        }
    }
    
    private func chooseOutputPath() {
        let panel = NSSavePanel()
        panel.title = "Save Exported Video"
        panel.allowedContentTypes = [.mpeg4Movie, .movie]
        let ext = selectedFormat == "MOV" ? "mov" : "mp4"
        panel.nameFieldStringValue = "OneLyrics_Export.\(ext)"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startExport() {
        let ext = selectedFormat == "MOV" ? "mov" : "mp4"
        let finalPath = outputPath.isEmpty ? NSHomeDirectory() + "/Desktop/OneLyrics_Export.\(ext)" : outputPath
        
        // Ensure extension matches format
        var url = URL(fileURLWithPath: finalPath)
        if url.pathExtension.lowercased() != ext {
            url = url.deletingPathExtension().appendingPathExtension(ext)
        }
        
        exporter.export(
            store: store,
            format: selectedFormat,
            resolution: selectedResolution,
            bitrate: selectedBitrate,
            outputURL: url
        )
    }
}
