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
                    .frame(width: 150, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)
                    .rotationEffect(.degrees(Double(index * 5) - 5))
                    .offset(x: CGFloat(index * 20) - 20, y: 0)
                    .zIndex(Double(maxCovers - index))
            }
            
            // Si no hay libros, mostrar un placeholder
            if books.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 150, height: 220)
                    
                    Image(systemName: "books.vertical")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: 200, height: 220)
    }
    
    private func bookCover(for book: CompleteBook) -> some View {
        Group {
            if let coverPath = book.metadata.coverPath,
               let coverImage = UIImage(contentsOfFile: coverPath) {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
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

// Nueva vista para portadas alineadas
struct ScatteredCoversView: View {
    let books: [CompleteBook]
    let maxCovers: Int = 5
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 10) {
                Spacer(minLength: 16)
                
                // Mostrar hasta maxCovers portadas en línea horizontal
                ForEach(0..<min(books.count, maxCovers), id: \.self) { index in
                    bookCover(for: books[index])
                        .frame(width: 112, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                
                // Si no hay libros, mostrar un placeholder
                if books.isEmpty {
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 112, height: 168)
                        .overlay(
                            Image(systemName: "books.vertical")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                    Spacer()
                }
                
                Spacer(minLength: 16)
            }
            .frame(width: geometry.size.width)
        }
        .frame(height: 180)
    }
    
    private func bookCover(for book: CompleteBook) -> some View {
        Group {
            if let coverPath = book.metadata.coverPath,
               let coverImage = UIImage(contentsOfFile: coverPath) {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
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