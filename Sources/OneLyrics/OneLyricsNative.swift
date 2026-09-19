import SwiftUI
import AVFoundation
import AppKit

@main
struct OneLyricsNativeApp: App {
    @StateObject private var projectStore = ProjectStore()
    
    init() {
        // Register locally downloaded fonts dynamically on app launch
        FontManager.shared.loadLocalFonts()
        
        // Global spacebar monitor - runs at app level, always works
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 { // 49 = Spacebar
                // Don't intercept if user is typing in a text field
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSTextView {
                    return event
                }
                NotificationCenter.default.post(name: .spacebarPressed, object: nil)
                return nil // swallow the event
            }
            return event
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectStore)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .onReceive(NotificationCenter.default.publisher(for: .spacebarPressed)) { _ in
                    projectStore.togglePlayPause()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

extension Notification.Name {
    static let spacebarPressed = Notification.Name("spacebarPressed")
}
