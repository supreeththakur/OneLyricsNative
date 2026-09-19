import SwiftUI

struct FontManagerView: View {
    @StateObject private var manager = FontManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Font Downloader")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            List {
                ForEach(manager.catalog) { font in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(font.familyName)
                                .font(.system(size: 14, weight: .bold))
                            Text(font.category)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        if manager.localFonts.contains(font.familyName) {
                            Text("Installed")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        } else if manager.downloadingFonts.contains(font.familyName) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Download") {
                                manager.downloadFont(font)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
    }
}
