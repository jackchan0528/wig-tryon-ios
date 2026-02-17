import SwiftUI

struct WigSelectorView: View {
    @ObservedObject var wigManager: WigManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
    }
}

struct WigThumbnail: View {
    let wig: Wig
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: 42, height: 42)

            if let thumbnail = wig.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
        }
        .overlay(
            Circle()
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                .frame(width: 42, height: 42)
        )
    }
}

#Preview {
    WigSelectorView(wigManager: WigManager())
        .background(Color.black)
}
