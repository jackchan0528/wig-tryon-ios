import SwiftUI

struct WigSelectorView: View {
    @ObservedObject var wigManager: WigManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(wigManager.wigs) { wig in
                    WigThumbnail(
                        wig: wig,
                        isSelected: wigManager.currentWig?.id == wig.id
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            wigManager.selectWig(wig)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }
}

struct WigThumbnail: View {
    let wig: Wig
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 56, height: 56)
                
                if let thumbnail = wig.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )
            
            // Name
            Text(wig.name)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

#Preview {
    WigSelectorView(wigManager: WigManager())
        .background(Color.black)
}
