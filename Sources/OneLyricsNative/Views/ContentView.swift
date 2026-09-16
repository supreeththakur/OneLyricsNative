import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        NavigationView {
            // Sidebar (Assets)
            AssetSidebar()
                .frame(minWidth: 250)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Player View
                PlayerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
                // Timeline View
                TimelineView()
                    .frame(height: 250)
                    .background(Color(white: 0.1))
            }
            
            // Inspector (Settings)
            InspectorSidebar()
                .frame(minWidth: 300)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(store.state.title)
                    .font(.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Export Video") {
                    // Export Action
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}
