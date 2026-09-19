import Foundation
import CoreGraphics
import CoreText
import AppKit

struct FontEntry: Identifiable, Codable {
    var id: String { familyName }
    let familyName: String
    let urlString: String
    let category: String
}

class FontManager: ObservableObject {
    static let shared = FontManager()
    
    @Published var availableFonts: [String] = ["Inter", "Georgia", "Courier", "Helvetica", "Avenir"]
    @Published var downloadingFonts: Set<String> = []
    @Published var localFonts: Set<String> = [] // Fonts that have been downloaded
    
    let catalog: [FontEntry] = [
        FontEntry(familyName: "Oswald", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/oswald/Oswald%5Bwght%5D.ttf", category: "Display"),
        FontEntry(familyName: "Bebas Neue", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf", category: "Display"),
        FontEntry(familyName: "Pacifico", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf", category: "Handwriting"),
        FontEntry(familyName: "Dancing Script", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/dancingscript/DancingScript%5Bwght%5D.ttf", category: "Handwriting"),
        FontEntry(familyName: "Montserrat", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf", category: "Sans Serif"),
        FontEntry(familyName: "Playfair Display", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf", category: "Serif"),
        FontEntry(familyName: "Lobster", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/lobster/Lobster-Regular.ttf", category: "Display"),
        FontEntry(familyName: "Righteous", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/righteous/Righteous-Regular.ttf", category: "Display"),
        FontEntry(familyName: "Permanent Marker", urlString: "https://raw.githubusercontent.com/google/fonts/main/apache/permanentmarker/PermanentMarker-Regular.ttf", category: "Handwriting"),
        FontEntry(familyName: "Abril Fatface", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/abrilfatface/AbrilFatface-Regular.ttf", category: "Display"),
        FontEntry(familyName: "Cinzel", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf", category: "Serif"),
        FontEntry(familyName: "Russo One", urlString: "https://raw.githubusercontent.com/google/fonts/main/ofl/russoone/RussoOne-Regular.ttf", category: "Sans Serif")
    ]
    
    private var fontsDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = paths[0].appendingPathComponent("OneLyricsNative", isDirectory: true)
        let fontDir = appDir.appendingPathComponent("Fonts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: fontDir.path) {
            try? FileManager.default.createDirectory(at: fontDir, withIntermediateDirectories: true)
        }
        return fontDir
    }
    
    func loadLocalFonts() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: fontsDirectory, includingPropertiesForKeys: nil) else { return }
        
        for file in files where file.pathExtension == "ttf" || file.pathExtension == "otf" {
            let fileName = file.deletingPathExtension().lastPathComponent
            
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(file as CFURL, .process, &error)
            
            // Try to match file name to catalog family name
            let entry = catalog.first(where: { fileName == $0.familyName.replacingOccurrences(of: " ", with: "") })
            let familyName = entry?.familyName ?? fileName
            
            DispatchQueue.main.async {
                if !self.availableFonts.contains(familyName) {
                    self.availableFonts.append(familyName)
                }
                self.localFonts.insert(familyName)
            }
        }
    }
    
    func downloadFont(_ entry: FontEntry) {
        guard let url = URL(string: entry.urlString) else { return }
        
        DispatchQueue.main.async {
            self.downloadingFonts.insert(entry.familyName)
        }
        
        let destination = fontsDirectory.appendingPathComponent("\(entry.familyName.replacingOccurrences(of: " ", with: "")).ttf")
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            defer {
                DispatchQueue.main.async {
                    self.downloadingFonts.remove(entry.familyName)
                }
            }
            
            if let localURL = localURL {
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.moveItem(at: localURL, to: destination)
                    
                    var registerError: Unmanaged<CFError>?
                    CTFontManagerRegisterFontsForURL(destination as CFURL, .process, &registerError)
                    
                    DispatchQueue.main.async {
                        if !self.availableFonts.contains(entry.familyName) {
                            self.availableFonts.append(entry.familyName)
                        }
                        self.localFonts.insert(entry.familyName)
                    }
                } catch {
                    print("Error moving downloaded font: \(error)")
                }
            }
        }
        task.resume()
    }
}
