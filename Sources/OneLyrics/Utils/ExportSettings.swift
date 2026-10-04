import Foundation
import SwiftUI

struct ExportSettingsData: Codable, Equatable {
    var format: String = "MP4"
    var resolution: String = "1080p"
    var bitrate: String = "High"
    var uploadToYouTube: Bool = false
    
    static let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent(".onelyrics")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("export_settings.json")
    }()
    
    static func load() -> ExportSettingsData {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(ExportSettingsData.self, from: data) else {
            return ExportSettingsData()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: ExportSettingsData.fileURL, options: .atomic)
        }
    }
}

class ExportSettingsManager: ObservableObject {
    static let shared = ExportSettingsManager()
    
    @Published var settings: ExportSettingsData {
        didSet {
            settings.save()
        }
    }
    
    init() {
        self.settings = ExportSettingsData.load()
        
        // Watch for changes on disk (if the other app changes it)
        NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }
    
    func reload() {
        let loaded = ExportSettingsData.load()
        if loaded != self.settings {
            self.settings = loaded
        }
    }
}
