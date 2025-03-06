import SwiftUI
import Combine

struct BookItemView: View {
    let book: CompleteBook
    var displayMode: DisplayMode = .grid
    var onDelete: (() -> Void)?
    @State private var isShowingDeleteMenu = false

    enum DisplayMode {
        case grid, list, large
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                // Container principal
                bookCover
                    .overlay(gradientOverlay)
                    .overlay(progressPercentageOverlay, alignment: .bottomTrailing)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                // Barra de progreso principal
                if displayMode != .list {
                    ProgressBar(value: book.book.progress)
                        .frame(height: 3)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 1)
                }
            }
            .aspectRatio(0.68, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .onLongPressGesture {
                isShowingDeleteMenu = true
            }
            .contextMenu {
                Button(action: {
                    onDelete?()
                }) {
                    Label("Eliminar", systemImage: "trash")
                }
            }

            if displayMode != .large {
                bookInfo
            }
        }
        .padding(.vertical, 4)
        .alert(isPresented: $isShowingDeleteMenu) {
            Alert(
                title: Text("Eliminar libro"),
                message: Text("¿Estás seguro de que quieres eliminar este libro?"),
                primaryButton: .destructive(Text("Eliminar")) {
                    onDelete?()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var bookCover: some View {
        Group {
            if let coverPath = book.metadata.coverPath,
               let coverImage = UIImage(contentsOfFile: coverPath) {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                .clear,
                .clear,
                .black.opacity(0.15),
                .black.opacity(0.3)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var progressPercentageOverlay: some View {
        Group {
            if book.book.progress > 0 && displayMode != .list {
                Text("\(Int(book.book.progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding([.horizontal, .bottom], 8)
                    .padding(.top, 6)
            }
        }
    }

    private var bookInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.book.title)
                .font(.system(size: displayMode == .large ? 15 : 13, weight: .medium))
                .lineLimit(displayMode == .large ? 2 : 1)
                .foregroundColor(.primary)

            Text(book.book.author)
                .font(.system(size: displayMode == .large ? 13 : 11))
                .lineLimit(1)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                typeBadge

                if let issue = book.book.issueNumber {
                    Text("#\(issue)")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
    }

    private var typeBadge: some View {
        Text(book.book.type.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    private var badgeColor: Color {
        switch book.book.type {
        case .epub: return .blue
        case .pdf: return .red
        case .cbr, .cbz: return .purple
        }
    }
}

// Definición de ProgressBar (si no está definida en otro archivo accesible)
struct ProgressBar: View {
    var value: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width)
                    .opacity(0.15)
                    .foregroundColor(.primary)

                Rectangle()
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width))
                    .foregroundColor(.blue)
                    .animation(.easeInOut, value: value)
            }
        }
        .frame(height: height)
        .cornerRadius(height/2)
    }
}
