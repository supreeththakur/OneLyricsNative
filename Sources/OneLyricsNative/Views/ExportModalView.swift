import SwiftUI

struct ExportModalView: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    
    @State private var selectedFormat = "MP4"
    @State private var selectedResolution = "1080p"
    @State private var selectedBitrate = "High"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export Video")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Format").foregroundColor(.gray)
                Picker("", selection: $selectedFormat) {
                    Text("MP4 (H.264)").tag("MP4")
                    Text("MOV (ProRes)").tag("MOV")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution").foregroundColor(.gray)
                Picker("", selection: $selectedResolution) {
                    Text("1080p").tag("1080p")
                    Text("4K").tag("4K")
                    Text("Vertical (9:16)").tag("Vertical")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality / Bitrate").foregroundColor(.gray)
                Picker("", selection: $selectedBitrate) {
                    Text("Standard").tag("Standard")
                    Text("High").tag("High")
                    Text("Lossless").tag("Lossless")
                }
                .pickerStyle(.segmented)
            }
            
            Spacer()
            
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
                    // TODO: trigger AVAssetWriter export
                    isPresented = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(30)
        .frame(width: 450, height: 400)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}
