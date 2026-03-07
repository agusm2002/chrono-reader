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
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width - 40, height: geometry.size.height - 20)
                            .clipped()
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
                // Animamos la aparición con un pequeño retraso para dar efecto de cascada
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.8)) {
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
            .frame(width: 150, height: 225)
            .overlay(
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
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
                        bookCoverForScattered(for: books[index])
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
    
    // Función que retorna una vista específica para portadas
    private func bookCoverForScattered(for book: CompleteBook) -> some View {
        if let coverPath = book.metadata.coverPath,
            let coverImage = UIImage(contentsOfFile: coverPath) {
            return AnyView(
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            )
        } else {
            return AnyView(
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            )
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
            if let coverPath = book.metadata.coverPath {
                // Usamos Image directamente en lugar de cargar el UIImage para mejor rendimiento
                AsyncImage(url: URL(fileURLWithPath: coverPath)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 112, height: 168)
                            .clipped()
                    } else {
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
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
    
    private var placeholderImage: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "book.closed")
                .font(.title)
                .foregroundColor(.gray)
        }
    }
}

// Nueva vista para mostrar colecciones en el home con portadas bien recortadas
struct HomeCollectionView: View {
    let books: [CompleteBook]
    @State private var isVisible = false
    @State private var isHovered = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fondo degradado suave
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.2),
                                Color(.systemBackground).opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                
                if books.isEmpty {
                    // Si no hay libros, mostrar un placeholder
                    placeholderForHome
                        .frame(width: 140, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 1, y: 2)
                        .opacity(isVisible ? 1 : 0)
                        .scaleEffect(isVisible ? 1 : 0.8)
                        .blur(radius: isVisible ? 0 : 2)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isVisible)
                } else {
                    // Distribución de portadas desde el centro hacia los lados
                    bookCoversLayout(
                        books: books,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation {
                    isHovered = hovering
                }
            }
            .onAppear {
                // Animamos la aparición con un pequeño retraso para dar efecto de cascada
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isVisible = true
                    }
                }
            }
            .onDisappear {
                // Reseteamos el estado cuando la vista desaparece
                isVisible = false
                isHovered = false
            }
        }
    }
    
    // Placeholder para cuando no hay portadas
    private var placeholderForHome: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "book.closed")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
    // Layout de portadas de libros
    @ViewBuilder
    private func bookCoversLayout(books: [CompleteBook], containerWidth: CGFloat, containerHeight: CGFloat) -> some View {
        let displayBooks = Array(books.prefix(min(5, books.count)))
        
        switch displayBooks.count {
        case 1:
            // Solo una portada
            bookCoverViewForHome(
                book: displayBooks[0],
                width: 160,
                height: 230,
                rotation: 0,
                xOffset: 0,
                yOffset: 0,
                isCenter: true,
                index: 0
            )
            
        case 2:
            // Dos portadas, principal a la izquierda
            ZStack {
                bookCoverViewForHome(
                    book: displayBooks[0],
                    width: 160,
                    height: 230,
                    rotation: 0,
                    xOffset: -40,
                    yOffset: 0,
                    isCenter: true,
                    index: 0
                )
                .zIndex(100)
                
                bookCoverViewForHome(
                    book: displayBooks[1],
                    width: 130,
                    height: 190,
                    rotation: 8,
                    xOffset: 50,
                    yOffset: 5,
                    isCenter: false,
                    index: 1
                )
                .zIndex(90)
            }
            
        case 3:
            // Tres portadas, la central es la principal
            ZStack {
                bookCoverViewForHome(
                    book: displayBooks[0],
                    width: 130,
                    height: 190,
                    rotation: -8,
                    xOffset: -90,
                    yOffset: 5,
                    isCenter: false,
                    index: 0
                )
                .zIndex(80)
                
                bookCoverViewForHome(
                    book: displayBooks[1],
                    width: 160,
                    height: 230,
                    rotation: 0,
                    xOffset: 0,
                    yOffset: 0,
                    isCenter: true,
                    index: 1
                )
                .zIndex(100)
                
                bookCoverViewForHome(
                    book: displayBooks[2],
                    width: 130,
                    height: 190,
                    rotation: 8,
                    xOffset: 90,
                    yOffset: 5,
                    isCenter: false,
                    index: 2
                )
                .zIndex(90)
            }
            
        case 4:
            // Cuatro portadas, con la central principal y las demás alrededor
            ZStack {
                // Libro a la izquierda
                bookCoverViewForHome(
                    book: displayBooks[0],
                    width: 130,
                    height: 190,
                    rotation: -12,
                    xOffset: -115,
                    yOffset: 5,
                    isCenter: false,
                    index: 0
                )
                .zIndex(80)
                
                // Libro principal (central izquierda)
                bookCoverViewForHome(
                    book: displayBooks[1],
                    width: 160,
                    height: 230,
                    rotation: -3,
                    xOffset: -30,
                    yOffset: 0,
                    isCenter: true,
                    index: 1
                )
                .zIndex(100)
                
                // Libro a la derecha del centro
                bookCoverViewForHome(
                    book: displayBooks[2],
                    width: 130,
                    height: 190,
                    rotation: 5,
                    xOffset: 60,
                    yOffset: 5,
                    isCenter: false,
                    index: 2
                )
                .zIndex(90)
                
                // Libro más a la derecha
                bookCoverViewForHome(
                    book: displayBooks[3],
                    width: 130,
                    height: 190,
                    rotation: 12,
                    xOffset: 140,
                    yOffset: 5,
                    isCenter: false,
                    index: 3
                )
                .zIndex(70)
            }
            
        default: // 5 o más portadas - distribución equitativa desde el centro
            ZStack {
                // Libro más a la izquierda
                bookCoverViewForHome(
                    book: displayBooks[0],
                    width: 130,
                    height: 190,
                    rotation: -15,
                    xOffset: -150,
                    yOffset: 5,
                    isCenter: false,
                    index: 0
                )
                .zIndex(70)
                
                // Segundo libro desde la izquierda
                bookCoverViewForHome(
                    book: displayBooks[1],
                    width: 130,
                    height: 190,
                    rotation: -8,
                    xOffset: -75,
                    yOffset: 5,
                    isCenter: false,
                    index: 1
                )
                .zIndex(80)
                
                // Libro central (principal)
                bookCoverViewForHome(
                    book: displayBooks[2],
                    width: 160,
                    height: 230,
                    rotation: 0,
                    xOffset: 0,
                    yOffset: 0,
                    isCenter: true,
                    index: 2
                )
                .zIndex(100)
                
                // Segundo libro desde la derecha
                bookCoverViewForHome(
                    book: displayBooks[3],
                    width: 130,
                    height: 190,
                    rotation: 8,
                    xOffset: 75,
                    yOffset: 5,
                    isCenter: false,
                    index: 3
                )
                .zIndex(80)
                
                // Libro más a la derecha
                bookCoverViewForHome(
                    book: displayBooks[4],
                    width: 130,
                    height: 190,
                    rotation: 15,
                    xOffset: 150,
                    yOffset: 5,
                    isCenter: false,
                    index: 4
                )
                .zIndex(70)
            }
        }
    }
    
    // Vista para portada individual con efectos
    private func bookCoverViewForHome(
        book: CompleteBook,
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        xOffset: CGFloat,
        yOffset: CGFloat,
        isCenter: Bool,
        index: Int
    ) -> some View {
        VStack(spacing: 0) {
            // Portada
            bookCoverForHome(for: book)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(isCenter ? 0.35 : 0.25), radius: isCenter ? 8 : 5, x: 2, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            
            // Barra de progreso
            if book.book.progress > 0 {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * CGFloat(book.book.progress), height: 3)
                    .padding(.top, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scaleEffect(0.7)  // Empezamos con una escala menor para la animación
        .scaleEffect(isVisible ? (isCenter ? 1.5 : 1.429) : 1)  // Animación de escala compensada
        .rotationEffect(.degrees(isVisible ? (isHovered ? rotation * 0.7 : rotation) : rotation * 2))  // Animación de rotación
        .offset(x: isVisible ? xOffset : 0, y: isVisible ? yOffset : 15)  // Animación de posición
        .animation(
            .spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.7)
                .delay(0.15 + (0.12 * Double(index))),
            value: isVisible
        )
        .animation(
            .spring(response: 0.4, dampingFraction: 0.7),
            value: isHovered
        )
        .opacity(isVisible ? 1 : 0)
        .brightness(isHovered ? 0.04 : 0)
    }
    
    // Función para obtener portada de libro para el Home
    private func bookCoverForHome(for book: CompleteBook) -> some View {
        Group {
            if let coverPath = book.metadata.coverPath, FileManager.default.fileExists(atPath: coverPath),
               let uiImage = UIImage(contentsOfFile: coverPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // Función para formatear fechas
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