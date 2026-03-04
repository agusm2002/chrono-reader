import SwiftUI

struct ComicTopBar: View {
    @ObservedObject var model: ComicViewerModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(model.useWhiteBackground ? .black : .white)
                    .padding(12)
                    .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            
            Spacer()
            
            Text(model.book.displayTitle)
                .font(.headline)
                .foregroundColor(model.useWhiteBackground ? .black : .white)
                .lineLimit(1)
                .shadow(color: model.useWhiteBackground ? .clear : .black, radius: 2, x: 0, y: 1)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    model.showSettings = true
                }
            }) {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(model.useWhiteBackground ? .black : .white)
                    .padding(12)
                    .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 50)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    model.useWhiteBackground ? Color.white.opacity(0.7) : Color.black.opacity(0.7),
                    model.useWhiteBackground ? Color.white.opacity(0) : Color.black.opacity(0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
