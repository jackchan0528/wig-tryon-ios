import SwiftUI

struct WigSelectorView: View {
    @ObservedObject var wigManager: WigManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(wigManager.wigs) { wig in
                    WigThumbnail(
                        wig: wig,
                        isSelected: wigManager.currentWig?.id == wig.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            wigManager.selectWig(wig)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }
}

struct WigThumbnail: View {
    let wig: Wig
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.primary : Color(.systemFill))
                .frame(width: 42, height: 42)

            if let thumbnail = wig.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 37, height: 37)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    WigSelectorView(wigManager: WigManager())
        .background(Color.black)
}
