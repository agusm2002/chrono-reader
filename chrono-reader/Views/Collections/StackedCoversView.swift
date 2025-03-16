// StackedCoversView.swift

import SwiftUI

struct StackedCoversView: View {
    let books: [CompleteBook]
    let maxCovers: Int = 3
    
    var body: some View {
        ZStack {
            // Mostrar hasta 3 portadas escalonadas
            ForEach(0..<min(books.count, maxCovers), id: \.self) { index in
                bookCover(for: books[index])
                    .frame(width: 100, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)
                    .rotationEffect(.degrees(Double(index * 5) - 5))
                    .offset(x: CGFloat(index * 12) - 12, y: 0)
                    .zIndex(Double(maxCovers - index))
            }
            
            // Si no hay libros, mostrar un placeholder
            if books.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 140)
                    
                    Image(systemName: "books.vertical")
                        .font(.system(size: 36))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: 140, height: 140)
    }
    
    private func bookCover(for book: CompleteBook) -> some View {
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
} 