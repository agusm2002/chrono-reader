// StackedCoversView.swift

import SwiftUI
import CoreGraphics
import ImageIO

struct StackedCoversView: View {
    let books: [CompleteBook]
    @State private var isVisible = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Limitamos a 5 portadas como máximo
                let displayBooks = Array(books.prefix(min(5, books.count)))
                let centerIndex = (displayBooks.count - 1) / 2
                
                ForEach(Array(displayBooks.enumerated()), id: \.element.id) { index, book in
                    if let coverPath = book.metadata.coverPath {
                        // Usamos el sistema de caché
                        CachedImage(imagePath: coverPath, targetSize: CGSize(width: geometry.size.width - 40, height: geometry.size.height - 20))
                            .aspectRatio(0.68, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 2, y: 2)
                            .rotationEffect(.degrees(isVisible ? Double(index - centerIndex) * 3 : 0))
                            .offset(
                                x: isVisible ? CGFloat(index - centerIndex) * 35 : 0,
                                y: isVisible ? CGFloat(abs(index - centerIndex)) * 5 : 0
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.05 * Double(index)), value: isVisible)
                            .zIndex(Double(displayBooks.count - abs(index - centerIndex)))
                    } else {
                        // Placeholder para libros sin portada
                        placeholderCover
                            .rotationEffect(.degrees(isVisible ? Double(index - centerIndex) * 3 : 0))
                            .offset(
                                x: isVisible ? CGFloat(index - centerIndex) * 35 : 0,
                                y: isVisible ? CGFloat(abs(index - centerIndex)) * 5 : 0
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.05 * Double(index)), value: isVisible)
                            .zIndex(Double(displayBooks.count - abs(index - centerIndex)))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                // Animamos la aparición solo cuando realmente es visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isVisible = true
                    }
                }
            }
            .onDisappear {
                // Reseteamos el estado cuando la vista desaparece
                isVisible = false
            }
        }
    }
    
    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(0.68, contentMode: .fit)
            .overlay(
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // Función para hacer downsampling de imágenes según el tamaño de destino
    private func downsampleImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(image.pngData()! as CFData, imageSourceOptions) else {
            return image
        }
        
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * UIScreen.main.scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return image
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}

// Nueva vista para portadas alineadas
struct ScatteredCoversView: View {
    let books: [CompleteBook]
    let maxCovers: Int = 5
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: -20) {
                Spacer(minLength: 16)
                
                // Mostrar hasta maxCovers portadas en línea horizontal
                ForEach(0..<min(books.count, maxCovers), id: \.self) { index in
                    ZStack(alignment: .bottom) {
                        // Portada base
                        bookCover(for: books[index])
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                        
                        // Gradiente para mejorar legibilidad
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .clear,
                                .black.opacity(0.15),
                                .black.opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Barra de progreso
                        if books[index].book.progress > 0 {
                            VStack(spacing: 0) {
                                Spacer()
                                
                                // Etiquetas antes de la barra
                                HStack {
                                    // Fecha a la izquierda si está disponible
                                    if let lastReadDate = books[index].book.lastReadDate {
                                        Text(formatLastReadDate(lastReadDate))
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.black.opacity(0.4))
                                            .cornerRadius(3)
                                    }
                                    
                                    Spacer()
                                    
                                    // Porcentaje a la derecha
                                    Text("\(Int(books[index].book.progress * 100))%")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(3)
                                }
                                .padding(.horizontal, 4)
                                
                                // Barra de progreso
                                GeometryReader { barGeometry in
                                    ZStack(alignment: .leading) {
                                        // Fondo de la barra
                                        Rectangle()
                                            .fill(Color.white.opacity(0.2))
                                        
                                        // Progreso
                                        Rectangle()
                                            .fill(Color.white)
                                            .frame(width: barGeometry.size.width * books[index].book.progress)
                                    }
                                }
                                .frame(height: 2)
                            }
                        }
                    }
                    .frame(width: 112, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .rotationEffect(.degrees(Double(index) * 5))
                    .zIndex(Double(books.count - index))
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
        .mask(
            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .black,
                    .black,
                    .clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
    
    private func formatLastReadDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// Nueva vista para portadas animadas
struct AnimatedCoversView: View {
    let books: [CompleteBook]
    
    var body: some View {
        GeometryReader { geometry in
            let coverWidth: CGFloat = 112
            let spacing: CGFloat = 10
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    // Limitamos las repeticiones y usamos una vista más eficiente
                    ForEach(books.prefix(min(books.count, 10))) { book in
                        optimizedCoverView(for: book)
                    }
                }
                .padding(.horizontal, 16)
            }
            // Permitir interacción del usuario
        }
        .frame(height: 180)
    }
    
    // Vista optimizada para portadas
    private func optimizedCoverView(for book: CompleteBook) -> some View {
        ZStack(alignment: .bottom) {
            // Portada base con optimización
            optimizedBookCover(for: book)
                .aspectRatio(contentMode: .fill)
                .clipped()
            
            // Gradiente para mejorar legibilidad
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .clear,
                            .black.opacity(0.15),
                            .black.opacity(0.3)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Barra de progreso simplificada
            if book.book.progress > 0 {
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Porcentaje a la derecha (simplificado)
                    HStack {
                        Spacer()
                        Text("\(Int(book.book.progress * 100))%")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(3)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                    
                    // Barra de progreso
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 2)
                        .padding(.horizontal, 0)
                        .scaleEffect(x: CGFloat(book.book.progress), anchor: .leading)
                }
            }
        }
        .frame(width: 112, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }
    
    // Optimizado para mejor rendimiento
    private func optimizedBookCover(for book: CompleteBook) -> some View {
        Group {
            if let coverPath = book.metadata.coverPath {
                // Usamos Image directamente en lugar de cargar el UIImage para mejor rendimiento
                AsyncImage(url: URL(fileURLWithPath: coverPath)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "book.closed")
                .font(.title)
                .foregroundColor(.gray)
        }
    }
    
    private func formatLastReadDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
} 