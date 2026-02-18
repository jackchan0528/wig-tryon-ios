import SwiftUI

struct ControlsView: View {
    @ObservedObject var wigManager: WigManager
    @State private var tab: ControlTab = .rotate

    enum ControlTab: String, CaseIterable {
        case rotate   = "Rotate"
        case position = "Position"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Native segmented control
            Picker("Adjustment", selection: $tab) {
                ForEach(ControlTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)

            // Sliders
            VStack(spacing: 6) {
                if tab == .rotate {
                    sliderRow(label: "Spin",  value: $wigManager.rotationY, in: -180...180)
                    sliderRow(label: "Tilt",  value: $wigManager.rotationX, in: -180...180)
                    sliderRow(label: "Roll",  value: $wigManager.rotationZ, in: -180...180)
                } else {
                    sliderRow(label: "Scale", value: $wigManager.scale,   in: 0.5...1.5)
                    sliderRow(label: "X",     value: $wigManager.offsetX, in: -0.05...0.05)
                    sliderRow(label: "Y",     value: $wigManager.offsetY, in: -0.05...0.05)
                    sliderRow(label: "Depth", value: $wigManager.offsetZ, in: -0.05...0.05)
                }
            }

            // Reset
            Button {
                withAnimation { wigManager.reset() }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.primary)
        }
    }
}

#Preview {
    ControlsView(wigManager: WigManager())
        .background(.ultraThinMaterial)
}
