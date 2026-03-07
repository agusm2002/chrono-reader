//
//  BookGridView.swift
//
import SwiftUI

struct BookGridView: View {
    let books: [CompleteBook]

    // Using fixed columns with proper spacing
    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 36) {
            ForEach(books) { book in
                ZStack {
                    BookItemView(book: book)
                }
                .contentShape(Rectangle())
                .id(book.id) // Ensure unique identification
            }
        }
        .padding(.horizontal, 24)
    }
}

struct BookGridView_Previews: PreviewProvider {
    static var previews: some View {
        // Create some sample CompleteBook instances for the preview
        let sampleCompleteBooks: [CompleteBook] = Book.samples.map { book in
            CompleteBook(title: book.title, author: book.author, coverImage: book.coverImage, type: book.type, progress: book.progress)
        }
        return BookGridView(books: sampleCompleteBooks)
            .previewLayout(.sizeThatFits)
    }
}
