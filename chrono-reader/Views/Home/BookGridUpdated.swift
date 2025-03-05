import SwiftUI

struct BookGridUpdatedView: View {
    let books: [CompleteBook]
    var gridLayout: Int
    
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
                BookItemView(book: book, displayMode: .grid)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func listLayout() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(books) { book in
                    HStack(spacing: 12) {
                        BookItemView(book: book, displayMode: .list)
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
                    BookItemView(book: book, displayMode: .large)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.book.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(book.book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
