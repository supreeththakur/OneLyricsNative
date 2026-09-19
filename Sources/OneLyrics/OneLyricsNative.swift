import SwiftUI
import AVFoundation
import AppKit

@main
struct OneLyricsNativeApp: App {
    @StateObject private var projectManager = ProjectManager()
    @State private var activeProject: ProjectState? = nil
    
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
            if let project = activeProject {
                ProjectEditorWrapper(
                    project: project,
                    projectManager: projectManager,
                    onBack: { activeProject = nil }
                )
            } else {
                HomeView(projectManager: projectManager) { selectedProject in
                    activeProject = selectedProject
                }
            }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

struct ProjectEditorWrapper: View {
    @StateObject private var store: ProjectStore
    let projectManager: ProjectManager
    let onBack: () -> Void
    
    init(project: ProjectState, projectManager: ProjectManager, onBack: @escaping () -> Void) {
        _store = StateObject(wrappedValue: ProjectStore(initialState: project))
        self.projectManager = projectManager
        self.onBack = onBack
    }
    
    var body: some View {
        ContentView(onBack: {
            projectManager.saveProject(store.state)
            onBack()
        })
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .spacebarPressed)) { _ in
            store.togglePlayPause()
        }
        .onChange(of: store.state.title) { _ in projectManager.saveProject(store.state) }
        // We could observe other changes, but saving on back is explicitly implemented.
        // Also save periodically or on specific actions if needed.
    }
}

extension Notification.Name {
    static let spacebarPressed = Notification.Name("spacebarPressed")
}
