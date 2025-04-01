// StackedCoversView.swift

import SwiftUI

struct StackedCoversView: View {
    let books: [CompleteBook]
    let maxCovers: Int = 3
    
    var body: some View {
        ZStack {
            // Mostrar hasta 3 portadas escalonadas
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
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(3)
                            }
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)
                            
                            // Barra de progreso en el borde inferior
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Fondo de la barra
                                    Rectangle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(height: 3)
                                    
                                    // Progreso
                                    Rectangle()
                                        .fill(Color.blue) // Usar un color estándar aquí
                                        .frame(width: geo.size.width * CGFloat(books[index].book.progress), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                }
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
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(3)
                                }
                                .padding(.horizontal, 6)
                                .padding(.bottom, 4)
                                
                                // Barra de progreso en el borde inferior
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        // Fondo de la barra
                                        Rectangle()
                                            .fill(Color.black.opacity(0.7))
                                            .frame(height: 3)
                                        
                                        // Progreso
                                        Rectangle()
                                            .fill(Color.blue) // Usar un color estándar aquí
                                            .frame(width: geo.size.width * CGFloat(books[index].book.progress), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                    }
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
    @State private var currentOffset: CGFloat = 0
    @State private var movingForward = true
    
    // Velocidad base calculada para 5 libros en 20 segundos
    private let baseSpeed: Double = 20.0 / 5.0 // segundos por libro
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let coverWidth: CGFloat = 112
            let spacing: CGFloat = 10
            let totalContentWidth = CGFloat(books.count) * (coverWidth + spacing)
            let maxOffset = max(0, totalContentWidth - totalWidth + 32) // 32 for padding
            
            // Calcular la duración total basada en la cantidad de libros
            let animationDuration = Double(books.count) * baseSpeed
            
            HStack(spacing: spacing) {
                ForEach(0..<books.count, id: \.self) { index in
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
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(3)
                                }
                                .padding(.horizontal, 6)
                                .padding(.bottom, 4)
                                
                                // Barra de progreso en el borde inferior
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        // Fondo de la barra
                                        Rectangle()
                                            .fill(Color.black.opacity(0.7))
                                            .frame(height: 3)
                                        
                                        // Progreso
                                        Rectangle()
                                            .fill(Color.blue) // Usar un color estándar aquí
                                            .frame(width: geo.size.width * CGFloat(books[index].book.progress), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                    }
                    .frame(width: coverWidth, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 16)
            .offset(x: -currentOffset)
            .onAppear {
                guard books.count > 3 else { return }
                withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
                    currentOffset = maxOffset
                }
            }
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