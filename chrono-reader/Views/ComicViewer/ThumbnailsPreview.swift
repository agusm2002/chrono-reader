import SwiftUI
import UIKit

struct ThumbnailsPreview: View {
    let pages: [UIImage]
    let currentPage: Int
    let totalPages: Int
    let useWhiteBackground: Bool
    let onPageSelected: (Int) -> Void

    @State private var scrollViewWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Button(action: {
                                onPageSelected(index)
                            }) {
                                Image(uiImage: pages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 90)
                                    .cornerRadius(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(currentPage == index ? 
                                                    (useWhiteBackground ? Color.black : Color.white) : 
                                                    Color.clear, 
                                                   lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 10))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(5)
                                            .padding(2),
                                        alignment: .bottomTrailing
                                    )
                                    .id(index)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .onAppear {
                        scrollViewWidth = geometry.size.width
                        scrollToCurrentPage(scrollProxy: scrollProxy)
                    }
                    .onChange(of: currentPage) { _ in
                        scrollToCurrentPage(scrollProxy: scrollProxy)
                    }
                }
            }
        }
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(useWhiteBackground ? Color.white.opacity(0.8) : Color.black.opacity(0.5))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
    }

    private func scrollToCurrentPage(scrollProxy: ScrollViewProxy) {
        withAnimation {
            scrollProxy.scrollTo(currentPage, anchor: .center)
        }
    }
}
