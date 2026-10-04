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
                .frame(minWidth: 450, idealWidth: 450, minHeight: 600, idealHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
