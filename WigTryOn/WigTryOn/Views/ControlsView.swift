import SwiftUI

struct ControlsView: View {
    @ObservedObject var wigManager: WigManager
    @State private var tab: ControlTab = .rotate

    enum ControlTab: String, CaseIterable {
        case rotate = "Rotate"
        case position = "Position"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Tab picker
            HStack(spacing: 0) {
                ForEach(ControlTab.allCases, id: \.self) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { tab = t }
                    } label: {
                        Text(t.rawValue)
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(tab == t ? Color.white.opacity(0.25) : Color.clear)
                            .cornerRadius(6)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            // Sliders for active tab
            Group {
                if tab == .rotate {
                    compactSlider(icon: "arrow.triangle.2.circlepath", value: $wigManager.rotationY, range: -180...180)
                    compactSlider(icon: "arrow.up.and.down.circle", value: $wigManager.rotationX, range: -45...45)
                    compactSlider(icon: "rotate.right", value: $wigManager.rotationZ, range: -45...45)
                } else {
                    compactSlider(icon: "arrow.up.left.and.arrow.down.right", value: $wigManager.scale, range: 0.5...1.5)
                    compactSlider(icon: "arrow.left.and.right", value: $wigManager.offsetX, range: -0.05...0.05)
                    compactSlider(icon: "arrow.up.and.down", value: $wigManager.offsetY, range: -0.05...0.05)
                    compactSlider(icon: "arrow.up.arrow.down", value: $wigManager.offsetZ, range: -0.05...0.05)
                }
            }

            // Reset
            Button {
                wigManager.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.45))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func compactSlider(
        icon: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundColor(.white.opacity(0.7))
            Slider(value: value, in: range)
                .accentColor(.white)
        }
        .frame(height: 24)
    }
}

#Preview {
    ControlsView(wigManager: WigManager())
        .background(Color.gray)
}
