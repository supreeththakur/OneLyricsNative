import SwiftUI

struct OneLyricsExporterApp: App {
    init() {
        ExportManager.shared.startProcessing()
    }
    
    var body: some Scene {
        WindowGroup("OneLyrics Exporter") {
            MediaExporterView()
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 900)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
