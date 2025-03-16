// CollectionRowView.swift

import SwiftUI

// Importar el visor de cómics mejorado
import UIKit // Necesario para UIImage

struct CollectionRowView: View {
    let collection: Collection
    let books: [CompleteBook]
    var onDelete: (() -> Void)?
    
    var body: some View {
        NavigationLink(destination: CollectionDetailView(collection: collection, books: books)) {
            HStack(spacing: 24) {
                // Portadas escalonadas
                StackedCoversView(books: books)
                
                // Información de la colección
                VStack(alignment: .leading, spacing: 6) {
                    Text(collection.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(books.count) \(books.count == 1 ? "libro" : "libros")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Mostrar progreso general si hay libros
                    if !books.isEmpty {
                        let averageProgress = books.reduce(0.0) { $0 + $1.book.progress } / Double(books.count)
                        
                        HStack(spacing: 8) {
                            ProgressBar(value: averageProgress, height: 5, color: collection.color)
                                .frame(height: 5)
                            
                            Text("\(Int(averageProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(collection.color)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.vertical, 12)
                
                Spacer()
                
                // Botón de menú
                Menu {
                    Button(role: .destructive, action: {
                        onDelete?()
                    }) {
                        Label("Eliminar colección", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(height: 180)
            .background(
                ZStack {
                    // Fondo con blur al estilo Apple Books
                    if !books.isEmpty, let firstBook = books.first, let coverPath = firstBook.metadata.coverPath, let coverImage = UIImage(contentsOfFile: coverPath) {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 50)
                            .opacity(0.3)
                            .clipped()
                    }
                    
                    // Gradiente sobre el fondo
                    LinearGradient(
                        gradient: Gradient(colors: [
                            collection.color.opacity(0.2),
                            Color(.systemBackground).opacity(0.85)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Vista de detalle de la colección
struct CollectionDetailView: View {
    let collection: Collection
    let books: [CompleteBook]
    @State private var selectedBook: CompleteBook? = nil
    @State private var showingComicViewer = false
    @State private var animateTransition = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Encabezado
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(collection.color)
                        
                        Text("\(books.count) \(books.count == 1 ? "libro" : "libros")")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Grid de libros
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 20) {
                    ForEach(books) { book in
                        VStack(alignment: .leading, spacing: 8) {
                            // Portada del libro con gesto de toque
                            bookCover(for: book)
                                .aspectRatio(2/3, contentMode: .fit)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                .onTapGesture {
                                    if book.book.type == .cbz || book.book.type == .cbr {
                                        selectedBook = book
                                        
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            animateTransition = true
                                        }
                                        
                                        // Pequeño retraso para permitir que la animación comience
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            print("Abriendo cómic desde colección: \(book.book.title)")
                                            showingComicViewer = true
                                        }
                                    } else {
                                        // Para otros tipos de libros, podríamos implementar otra acción
                                        print("Abrir libro: \(book.book.title)")
                                    }
                                }
                                .scaleEffect(animateTransition && selectedBook?.id == book.id ? 1.05 : 1.0)
                                .brightness(animateTransition && selectedBook?.id == book.id ? 0.1 : 0)
                            
                            // Información del libro
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.book.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                
                                Text(book.book.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                // Barra de progreso
                                if book.book.progress > 0 {
                                    HStack(spacing: 4) {
                                        ProgressBar(value: book.book.progress, height: 4, color: collection.color)
                                            .frame(height: 4)
                                        
                                        Text("\(Int(book.book.progress * 100))%")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(collection.color)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingComicViewer, onDismiss: {
            // Resetear la animación cuando se cierra el visor
            withAnimation {
                animateTransition = false
            }
        }) {
            if let book = selectedBook {
                EnhancedComicViewer(book: book, onProgressUpdate: { updatedBook in
                    // Aquí podríamos actualizar el progreso si es necesario
                    print("Progreso actualizado: \(updatedBook.book.progress * 100)%")
                    
                    // Enviar notificación para actualizar el progreso
                    NotificationCenter.default.post(
                        name: Notification.Name("BookProgressUpdated"),
                        object: nil,
                        userInfo: ["book": updatedBook]
                    )
                })
            }
        }
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

// Vista previa
struct CollectionRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCollection = Collection(name: "Favoritos", color: .red)
        let sampleBooks = Book.samples.map { book in
            CompleteBook(
                title: book.title,
                author: book.author,
                coverImage: book.coverImage,
                type: book.type,
                progress: Double.random(in: 0...1)
            )
        }
        
        return CollectionRowView(collection: sampleCollection, books: sampleBooks)
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 