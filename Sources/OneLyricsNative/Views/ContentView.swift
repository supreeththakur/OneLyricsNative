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
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 { // Spacebar
                    // Check if user is typing in a text field
                    if let firstResponder = NSApp.keyWindow?.firstResponder {
                        let className = String(describing: type(of: firstResponder))
                        if className.contains("NSText") || className.contains("Field") {
                            return event
                        }
                    }
                    store.togglePlayPause()
                    return nil // swallow event
                }
                return event
            }
        }
    }
}


