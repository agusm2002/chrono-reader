//
//  BookGridView.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import SwiftUI

struct BookGridView: View {
    let books: [Book]
    
    // Using fixed columns with proper spacing
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(books) { book in
                BookItemView(book: book)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct BookGridView_Previews: PreviewProvider {
    static var previews: some View {
        BookGridView(books: Book.samples)
            .previewLayout(.sizeThatFits)
    }
}
