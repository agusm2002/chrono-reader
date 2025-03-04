import SwiftUI
import Combine

struct BookGridUpdatedView: View {
    let books: [CompleteBook]
    var gridLayout: Int = 0 // 0: Default, 1: List, 2: Large

    var body: some View {
        switch gridLayout {
        case 0:
            defaultGrid()
        case 1:
            listLayout()
        case 2:
            largeGrid()
        default:
            defaultGrid()
        }
    }

    // Default Grid Layout
    private func defaultGrid() -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(books) { book in
                BookItemView(book: book)
            }
        }
        .padding(.horizontal, 24)
    }

    // List Layout
    private func listLayout() -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(books) { book in
                    HStack {
                        // Book cover or placeholder
                        if let coverPath = book.metadata.coverPath,
                           let coverImage = UIImage(contentsOfFile: coverPath) {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 120)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 120)
                                .overlay(
                                    Image(systemName: "book.closed")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }

                        VStack(alignment: .leading) {
                            Text(book.book.title)
                                .font(.headline)
                            Text(book.book.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Large Grid Layout
    private func largeGrid() -> some View {
        let columns = [GridItem(.flexible())]
        
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(books) { book in
                VStack(alignment: .leading) {
                    // Book cover or placeholder
                    if let coverPath = book.metadata.coverPath,
                       let coverImage = UIImage(contentsOfFile: coverPath) {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "book.closed")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    Text(book.book.title)
                        .font(.headline)
                    Text(book.book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
}
