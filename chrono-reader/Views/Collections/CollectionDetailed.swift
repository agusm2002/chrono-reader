// CollectionDetailed.swift
// Esta extensión modifica cómo se muestran las portadas en la vista de colección

import SwiftUI

extension CollectionDetailView {
    // Función modificada para asegurar que las portadas se muestren correctamente
    func fixedBookCover(for book: CompleteBook) -> some View {
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
        .aspectRatio(2/3, contentMode: .fit)
    }
}

// Extension para aplicar restricciones de tamaño a imágenes
extension Image {
    func fixedCoverStyle() -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }
} 