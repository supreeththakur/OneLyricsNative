import SwiftUI
import AVFoundation

struct VisualizerEditorView: View {
    let onBack: () -> Void
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back to Home")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .padding()
                
                Spacer()
                
                Text(store.state.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Visualizer Editor")
                    .foregroundColor(.gray)
                    .padding()
            }
            .background(Color(white: 0.1))
            
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Audio Visualizer Editor")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming soon...")
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color.black)
    }
}
