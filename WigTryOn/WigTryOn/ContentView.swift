import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var wigManager = WigManager()
    @StateObject private var arTracker = ARFaceTracker()
    
    @State private var showControls = true
    @State private var capturedImage: UIImage?
    @State private var showSaveAlert = false
    
    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(tracker: arTracker, wigManager: wigManager)
                .edgesIgnoringSafeArea(.all)
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(arTracker.isFaceDetected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(arTracker.isFaceDetected ? "Face Detected" : "No Face")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    // Capture button
                    Button(action: capturePhoto) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                if showControls {
                    VStack(spacing: 16) {
                        // Wig name
                        Text(wigManager.currentWig?.name ?? "No Wig")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                        
                        // Wig selector
                        WigSelectorView(wigManager: wigManager)
                        
                        // Adjustment controls
                        ControlsView(wigManager: wigManager)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onTapGesture(count: 2) {
            withAnimation {
                showControls.toggle()
            }
        }
        .alert("Photo Saved!", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        }
    }
    
    private func capturePhoto() {
        // Capture AR view
        arTracker.capturePhoto { image in
            if let image = image {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                showSaveAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
}
