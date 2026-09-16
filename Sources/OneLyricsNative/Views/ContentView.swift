import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var showExportModal = false
    
    var body: some View {
        ZStack {
            // Main App
            HSplitView {
                // Left Sidebar - Assets
                AssetSidebar()
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 350)
                    .background(Color(white: 0.1))
                
                // Main Content Area
                VStack(spacing: 0) {
                    // Player View
                    PlayerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    
                    // Timeline View
                    TimelineView()
                        .frame(height: 260)
                }
                .frame(minWidth: 400, maxWidth: .infinity)
                
                // Inspector (Settings)
                InspectorSidebar()
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 350)
                    .background(Color(white: 0.1))
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text(store.state.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showExportModal = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Export Modal Overlay
            if showExportModal {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showExportModal = false }
                    .zIndex(100)
                
                ExportModalView(isPresented: $showExportModal)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        // Handle Global Spacebar Play/Pause
        .background(SpacebarHandler())
        .onReceive(NotificationCenter.default.publisher(for: .togglePlayback)) { _ in
            store.togglePlayPause()
        }
    }
}

// Invisible View to catch Spacebar presses globally
struct SpacebarHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Spacebar
            // Using NotificationCenter to broadcast play/pause since we can't easily inject the store here without generic wrappers
            NotificationCenter.default.post(name: .togglePlayback, object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

extension Notification.Name {
    static let togglePlayback = Notification.Name("togglePlayback")
}
