//
//  BookItemView.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import SwiftUI
import Combine

struct BookItemView: View {
    let book: Book
    @State private var coverImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            ZStack {
                // Portada del libro
                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .cornerRadius(8)
                } else if isLoading {
                    ProgressView()
                        .frame(height: 180)
                } else {
                    // Imagen de placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 180)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "book.closed")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                
                // Indicador de progreso
                VStack {
                    Spacer()
                    ProgressBar(value: book.progress)
                        .frame(height: 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Badges para el tipo y número de volumen/edición
                HStack {
                    Text(book.type.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor(for: book.type))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    if let issueNumber = book.issueNumber {
                        Text("#\(issueNumber)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    private func loadCoverImage() {
        guard let coverURL = book.coverURL else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: coverURL) { data, response, error in
            isLoading = false
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }.resume()
    }
    
    private func badgeColor(for type: BookType) -> Color {
        switch type {
        case .epub:
            return .blue
        case .pdf:
            return .red
        case .cbr, .cbz:
            return .purple
        }
    }
}

struct ProgressBar: View {
    var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(.blue)
            }
            .cornerRadius(45)
        }
    }
}
