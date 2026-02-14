import SwiftUI

struct ControlsView: View {
    @ObservedObject var wigManager: WigManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Scale slider
            HStack {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.white)
                
                Slider(value: $wigManager.scale, in: 0.5...1.5)
                    .accentColor(.white)
                
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            // Position controls
            HStack(spacing: 20) {
                // Vertical adjustment
                VStack(spacing: 4) {
                    Button(action: { wigManager.offsetY += 0.005 }) {
                        Image(systemName: "chevron.up")
                            .font(.title3)
                    }
                    
                    Text("Position")
                        .font(.caption2)
                    
                    Button(action: { wigManager.offsetY -= 0.005 }) {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                    }
                }
                .foregroundColor(.white)
                
                // Horizontal adjustment
                HStack(spacing: 20) {
                    Button(action: { wigManager.offsetX -= 0.005 }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }
                    
                    Button(action: { wigManager.offsetX += 0.005 }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                    }
                }
                .foregroundColor(.white)
                
                // Reset button
                Button(action: { wigManager.reset() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                        Text("Reset")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

#Preview {
    ControlsView(wigManager: WigManager())
        .background(Color.gray)
}
