import SwiftUI
import AVFoundation

@main
struct OneLyricsNativeApp: App {
    @StateObject private var projectStore = ProjectStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectStore)
                // Default dark mode appearance
                .preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
