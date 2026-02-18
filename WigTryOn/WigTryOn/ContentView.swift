import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var wigManager = WigManager()
    @StateObject private var arTracker = ARFaceTracker()

    @State private var showControls = false

    var body: some View {
        ZStack {
            ARViewContainer(tracker: arTracker, wigManager: wigManager)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Status indicator — top left
                HStack {
                    Circle()
                        .fill(arTracker.isFaceDetected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .padding(9)
                        .background(.ultraThinMaterial, in: Circle())
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom area
                VStack(spacing: 6) {
                    if showControls {
                        // Slide-up panel
                        VStack(spacing: 0) {
                            // Drag handle
                            Capsule()
                                .fill(.secondary.opacity(0.45))
                                .frame(width: 28, height: 4)
                                .padding(.top, 6)
                                .padding(.bottom, 2)

                            WigSelectorView(wigManager: wigManager)
                                .padding(.vertical, 2)

                            Divider()

                            ControlsView(wigManager: wigManager)
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Settings toggle button — always at bottom right
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showControls.toggle()
                            }
                        } label: {
                            Image(systemName: showControls ? "xmark" : "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview {
    ContentView()
}
