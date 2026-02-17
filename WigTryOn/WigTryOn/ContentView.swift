import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var wigManager = WigManager()
    @StateObject private var arTracker = ARFaceTracker()

    @State private var showControls = false
    @State private var capturedImage: UIImage?
    @State private var showSaveAlert = false

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(tracker: arTracker, wigManager: wigManager)
                .edgesIgnoringSafeArea(.all)

            // UI Overlay
            VStack(spacing: 0) {
                // Top bar — status dot, settings toggle, camera
                HStack {
                    Circle()
                        .fill(arTracker.isFaceDetected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    } label: {
                        Image(systemName: showControls ? "slider.horizontal.3" : "slider.horizontal.3")
                            .font(.body)
                            .foregroundColor(showControls ? .white : .white.opacity(0.5))
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Button(action: capturePhoto) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom controls
                if showControls {
                    VStack(spacing: 8) {
                        WigSelectorView(wigManager: wigManager)
                        ControlsView(wigManager: wigManager)
                    }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .alert("Photo Saved!", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func capturePhoto() {
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
