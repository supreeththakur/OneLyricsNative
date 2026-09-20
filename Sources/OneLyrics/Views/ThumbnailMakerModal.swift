import SwiftUI
import AppKit

struct ThumbnailMakerModal: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: ProjectStore
    
    @State private var previewImage: NSImage?
    @State private var thumbnailTextSize: CGFloat = 200
    @State private var thumbnailGlow: CGFloat = 20
    @State private var thumbnailShadowY: CGFloat = 0
    @State private var isExporting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "photo.artframe")
                    .foregroundColor(.orange)
                Text("Thumbnail Maker")
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
            
            HStack(spacing: 0) {
                // Preview Area
                VStack {
                    if let img = previewImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(8)
                            .shadow(radius: 10)
                            .padding()
                    } else {
                        Rectangle()
                            .fill(Color(white: 0.1))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                
                // Controls Sidebar
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Text Size")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(thumbnailTextSize))px")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $thumbnailTextSize, in: 50...500, step: 10)
                            .onChange(of: thumbnailTextSize) { _ in
                                generatePreview()
                            }
                        
                        HStack {
                            Text("Glow Blur")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(thumbnailGlow))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $thumbnailGlow, in: 0...100, step: 1)
                            .onChange(of: thumbnailGlow) { _ in
                                generatePreview()
                            }
                            
                        HStack {
                            Text("Shadow Offset Y")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(thumbnailShadowY))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $thumbnailShadowY, in: -50...50, step: 1)
                            .onChange(of: thumbnailShadowY) { _ in
                                generatePreview()
                            }
                    }
                    
                    Spacer()
                    
                    Button(action: exportThumbnail) {
                        HStack {
                            if isExporting {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("Export Thumbnail")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting || previewImage == nil)
                }
                .padding()
                .frame(width: 250)
                .background(Color(white: 0.15))
            }
        }
        .frame(width: 800, height: 480)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            thumbnailGlow = store.state.typography.glow
            generatePreview()
        }
    }
    
    private func generatePreview() {
        Task {
            let img = await ProjectThumbnailExporter.generateThumbnail(
                state: store.state,
                textSize: thumbnailTextSize,
                glow: thumbnailGlow,
                shadowOffset: CGSize(width: 0, height: -thumbnailShadowY)
            )
            await MainActor.run {
                self.previewImage = img
            }
        }
    }
    
    private func exportThumbnail() {
        guard let img = previewImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.nameFieldStringValue = "\(store.state.title) Thumbnail.jpg"
        
        if panel.runModal() == .OK, let url = panel.url {
            isExporting = true
            
            Task {
                if let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let rep = NSBitmapImageRep(cgImage: cgImage)
                    let ext = url.pathExtension.lowercased()
                    
                    let data: Data?
                    if ext == "png" {
                        data = rep.representation(using: .png, properties: [:])
                    } else {
                        data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                    }
                    
                    if let data = data {
                        do {
                            try data.write(to: url)
                        } catch {
                            print("Failed to save thumbnail: \(error)")
                        }
                    }
                }
                
                await MainActor.run {
                    self.isExporting = false
                    self.isPresented = false
                }
            }
        }
    }
}
