import SwiftUI

struct ControlsView: View {
    @ObservedObject var wigManager: WigManager

    var body: some View {
        VStack(spacing: 10) {
            // Size
            sliderRow(
                icon: "arrow.up.left.and.arrow.down.right",
                label: "Size",
                value: $wigManager.scale,
                range: 0.5...1.5
            )

            // Left / Right
            sliderRow(
                icon: "arrow.left.and.right",
                label: "L / R",
                value: $wigManager.offsetX,
                range: -0.05...0.05
            )

            // Up / Down
            sliderRow(
                icon: "arrow.up.and.down",
                label: "U / D",
                value: $wigManager.offsetY,
                range: -0.05...0.05
            )

            // Forward / Back (Z axis — negative Z is into the head)
            sliderRow(
                icon: "arrow.up.arrow.down",
                label: "F / B",
                value: $wigManager.offsetZ,
                range: -0.05...0.05
            )

            // Reset
            Button(action: { wigManager.reset() }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func sliderRow(
        icon: String,
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .frame(width: 32, alignment: .leading)
            Slider(value: value, in: range)
                .accentColor(.white)
        }
        .foregroundColor(.white)
    }
}

#Preview {
    ControlsView(wigManager: WigManager())
        .background(Color.gray)
}
