import SwiftUI

struct BookGridUpdatedView: View {
    let books: [CompleteBook]
    var gridLayout: Int
    var onDelete: ((CompleteBook) -> Void)? // Closure opcional para eliminar
    var onToggleFavorite: ((CompleteBook) -> Void)? // Closure opcional para toggle favorito
    
    // Constantes para mejorar el rendimiento
    private let defaultGridColumns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    private let largeGridColumns = [GridItem(.flexible(), spacing: 24)]
    
    var body: some View {
        Group {
            switch gridLayout {
            case 0: defaultGrid()
            case 1: listLayout()
            case 2: largeGrid()
            default: defaultGrid()
            }
        }
    }
    
    private func defaultGrid() -> some View {
        ScrollView {
            LazyVGrid(columns: defaultGridColumns, spacing: 24) {
                ForEach(books) { book in
                    // Usamos ID para ayudar a SwiftUI a identificar y reciclar vistas
                    BookItemView(book: book, displayMode: .grid, 
                                onDelete: {
                                    onDelete?(book)
                                },
                                onToggleFavorite: {
                                    onToggleFavorite?(book)
                                })
                    .id(book.id)
                    // Contenedor con tamaño fijo para evitar recálculos
                    .frame(width: UIScreen.main.bounds.width / 2 - 30)
                    // Uso de transaction para mejorar renderizado en scroll
                    .transaction { transaction in
                        transaction.animation = nil // Desactivamos animación en scroll
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        // Optimización del scroll
        .scrollIndicators(.hidden)
    }
    
    private func listLayout() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(books) { book in
                    HStack(spacing: 12) {
                        // La vista del libro es reutilizable
                        BookItemView(book: book, displayMode: .list, 
                                    onDelete: {
                                        onDelete?(book)
                                    },
                                    onToggleFavorite: {
                                        onToggleFavorite?(book)
                                    })
                        .id(book.id)
                        .frame(width: 80, height: 120) // Altura fija para mejorar rendimiento
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.displayTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            
                            Text(book.book.author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                ProgressBar(value: book.book.progress, height: 5, color: Color.appTheme())
                                    .frame(height: 5)
                                
                                Text("\(Int(book.book.progress * 100))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.appTheme())
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        
                        Spacer()
                    }
                    .id(book.id) // ID adicional para ayudar al sistema de diferenciación
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                    )
                    // Evitar animaciones en scroll
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
            .padding(.vertical, 16)
        }
        // Optimización del scroll
        .scrollIndicators(.hidden)
    }
    
    private func largeGrid() -> some View {
        ScrollView {
            LazyVGrid(columns: largeGridColumns, spacing: 24) {
                ForEach(books) { book in
                    VStack(alignment: .leading, spacing: 12) {
                        BookItemView(book: book, displayMode: .large, 
                                    onDelete: {
                                        onDelete?(book)
                                    },
                                    onToggleFavorite: {
                                        onToggleFavorite?(book)
                                    })
                        .id(book.id)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.displayTitle)
                                .font(.headline)
                                .lineLimit(2)
                            
                            if let localURL = book.metadata.localURL,
                               let fileSize = try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 {
                                // Extraemos la vista de etiquetas a una función para mejorar rendimiento
                                bookBadges(book: book, fileSize: fileSize)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    // Evitar animaciones en scroll
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
        }
        // Optimización del scroll
        .scrollIndicators(.hidden)
    }
    
    // Extraer las etiquetas a una función mejora el rendimiento
    private func bookBadges(book: CompleteBook, fileSize: Int64) -> some View {
        HStack(spacing: 4) {
            let fileSizeString = formatFileSize(fileSize)
            Text(fileSizeString)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
            
            Text(book.book.type.rawValue.uppercased())
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(4)
            
            if let issue = book.book.issueNumber {
                Text("#\(issue)")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func badgeColor(for type: BookType) -> Color {
        switch type {
        case .epub: return Color(red: 0.3, green: 0.6, blue: 0.9)
        case .pdf: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .cbr, .cbz: return Color(red: 0.7, green: 0.4, blue: 0.9)
        case .m4b: return Color(red: 0.3, green: 0.8, blue: 0.5) // Color verde-azulado para audiolibros
        }
    }
}
