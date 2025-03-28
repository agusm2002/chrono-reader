// ImageExtensions.swift
// Extensiones para mejorar la visualización de imágenes de portada

import SwiftUI

extension Image {
    /// Aplica un estilo de portada consistente, asegurando que la imagen se recorte al tamaño deseado
    func bookCoverStyle(cornerRadius: CGFloat = 8) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Aplica un estilo de portada con restricciones de proporción 2:3
    func standardCoverStyle(cornerRadius: CGFloat = 8) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Vista que convierte cualquier imagen en una portada bien formateada
struct BookCoverView: View {
    let coverPath: String?
    let cornerRadius: CGFloat
    
    init(coverPath: String?, cornerRadius: CGFloat = 8) {
        self.coverPath = coverPath
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let coverPath = coverPath,
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// INSTRUCCIONES DE USO:
//
// Para corregir las portadas en CollectionDetailView, modifica la parte de la
// vista detalle con esto:
/*
    VStack(alignment: .leading, spacing: 8) {
        Group {
            bookCover(for: book)
                .aspectRatio(contentMode: .fill)
                .clipped()
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
*/ 