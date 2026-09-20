import SwiftUI
import AVFoundation

struct ProjectThumbnailView: View {
    let url: URL?
    @State private var thumbnail: NSImage?
    
    var body: some View {
        Color(white: 0.15)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Group {
                    if let img = thumbnail {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: 30))
                            .foregroundColor(Color.white.opacity(0.2))
                    }
                }
            )
            .clipped()
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let url = url, FileManager.default.fileExists(atPath: url.path) else { return }
        let ext = url.pathExtension.lowercased()
        
        if ["mp4", "mov"].contains(ext) {
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 500, height: 500)
                
                do {
                    let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    DispatchQueue.main.async {
                        self.thumbnail = nsImage
                    }
                } catch {
                    print("Thumbnail generation failed: \(error)")
                }
            }
        } else {
            // Assume image
            DispatchQueue.global(qos: .userInitiated).async {
                if let nsImage = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.thumbnail = nsImage
                    }
                }
            }
        }
    }
}
