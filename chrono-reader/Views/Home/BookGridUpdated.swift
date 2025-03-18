import SwiftUI

struct BookGridUpdatedView: View {
    let books: [CompleteBook]
    var gridLayout: Int
    var onDelete: ((CompleteBook) -> Void)? // Closure opcional para eliminar
    var onToggleFavorite: ((CompleteBook) -> Void)? // Closure opcional para toggle favorito
    
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
        let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(books) { book in
                BookItemView(book: book, displayMode: .grid, 
                             onDelete: {
                    onDelete?(book)
                },
                             onToggleFavorite: {
                    onToggleFavorite?(book)
                })
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func listLayout() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(books) { book in
                    HStack(spacing: 12) {
                        BookItemView(book: book, displayMode: .list, 
                                     onDelete: {
                            onDelete?(book)
                        },
                                     onToggleFavorite: {
                            onToggleFavorite?(book)
                        })
                        .frame(width: 80)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.book.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(book.book.author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                ProgressBar(value: book.book.progress, height: 5)
                                    .frame(height: 5)
                                
                                Text("\(Int(book.book.progress * 100))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                    )
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    private func largeGrid() -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 1)
        
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(books) { book in
                VStack(alignment: .leading, spacing: 12) {
                    BookItemView(book: book, displayMode: .large, 
                                 onDelete: {
                        onDelete?(book)
                    },
                                 onToggleFavorite: {
                        onToggleFavorite?(book)
                    })
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.book.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        if let localURL = book.metadata.localURL,
                           let fileSize = try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 {
                            HStack(spacing: 4) {
                                let fileSizeString = formatFileSize(fileSize)
                                Text(fileSizeString)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(4)
                                
                                Text(book.book.type.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(badgeColor(for: book.book.type))
                                    .foregroundColor(.white)
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
                    }
                }
                .padding(.horizontal, 20)
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
        }
    }
}
