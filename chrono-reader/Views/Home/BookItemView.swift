import SwiftUI
import Combine

struct BookItemView: View {
    let book: CompleteBook
    var displayMode: DisplayMode = .grid
    var onDelete: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    @State private var isShowingDeleteMenu = false
    @State private var isShowingComicViewer = false
    @State private var isShowingEPUBViewer = false
    @State private var animateTransition = false

    enum DisplayMode {
        case grid, list, large
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Containment wrapper to prevent hitbox overflow
            ZStack {
                // Portada con overlays
                ZStack(alignment: .bottom) {
                    bookCover
                        .overlay(gradientOverlay)
                        .overlay(progressPercentageOverlay, alignment: .bottomTrailing)
                        .overlay(favoriteIndicator, alignment: .topTrailing)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(0.68, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .scaleEffect(animateTransition ? 1.05 : 1.0)
                .brightness(animateTransition ? 0.1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    animateTransition = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("Abriendo libro: \(book.book.title) con progreso: \(book.book.progress * 100)%")
                    
                    // Determinar qué visor abrir basado en el tipo de libro
                    switch book.book.type {
                    case .cbz, .cbr:
                        isShowingComicViewer = true
                    case .epub:
                        isShowingEPUBViewer = true
                    default:
                        // Otros tipos de libros
                        break
                    }
                }
            }
            .onLongPressGesture {
                isShowingDeleteMenu = true
            }
            .contextMenu {
                Button(action: {
                    onToggleFavorite?()
                }) {
                    Label(book.book.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos", 
                          systemImage: book.book.isFavorite ? "star.fill" : "star")
                }
                
                Button(action: {
                    onDelete?()
                }) {
                    Label("Eliminar", systemImage: "trash")
                }
            }
            .id(book.id) // Ensure each book has a unique identity
            
            // Barra de progreso standalone, debajo de la portada
            if book.book.progress > 0 && displayMode != .list {
                HStack {
                    ProgressBar(value: book.book.progress, height: 6, color: .blue)
                        .frame(height: 6)
                    
                    Text("\(Int(book.book.progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.appTheme())
                }
                .padding(.horizontal, 2)
                .id(book.book.progress)
            }

            if displayMode != .large {
                bookInfo
            }
        }
        .padding(.vertical, 4)
        // Comic Viewer
        .fullScreenCover(isPresented: $isShowingComicViewer, onDismiss: {
            withAnimation {
                animateTransition = false
            }
        }) {
            EnhancedComicViewer(book: book, onProgressUpdate: { updatedBook in
                print("BookItemView recibió actualización de progreso: \(updatedBook.book.progress * 100)%")
                
                NotificationCenter.default.post(
                    name: Notification.Name("BookProgressUpdated"),
                    object: nil,
                    userInfo: ["book": updatedBook]
                )
            })
            .transition(.opacity)
        }
        // EPUB Viewer
        .fullScreenCover(isPresented: $isShowingEPUBViewer, onDismiss: {
            withAnimation {
                animateTransition = false
            }
        }) {
            EPUBViewerView(book: book)
                .transition(.opacity)
        }
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
                GeometryReader { geometry in
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                }
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundColor(.gray)
                        .allowsHitTesting(false)
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
                VStack(alignment: .trailing, spacing: 2) {
                    if let lastReadDate = book.book.lastReadDate {
                        Text(formatLastReadDate(lastReadDate))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appTheme().opacity(0.7))
                            .cornerRadius(4)
                            .id("date-\(book.id)-\(lastReadDate.timeIntervalSince1970)")
                    }
                }
                .padding([.horizontal, .bottom], 8)
                .padding(.top, 6)
            }
        }
    }
    
    private func formatLastReadDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private var bookInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.book.title)
                .font(.system(size: displayMode == .large ? 15 : 13, weight: .medium))
                .lineLimit(displayMode == .large ? 2 : 1)
                .foregroundColor(.primary)

            if let localURL = book.metadata.localURL,
               let fileSize = try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 {
                HStack(spacing: 4) {
                    Text(formatFileSize(fileSize))
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    
                    if let pageCount = book.book.pageCount, pageCount > 0 {
                        Text("\(pageCount) págs.")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
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
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
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
        case .epub: return Color(red: 0.3, green: 0.6, blue: 0.9)
        case .pdf: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .cbr, .cbz: return Color(red: 0.7, green: 0.4, blue: 0.9)
        }
    }

    private var favoriteIndicator: some View {
        Group {
            if book.book.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                    .padding(8)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
    }
}
