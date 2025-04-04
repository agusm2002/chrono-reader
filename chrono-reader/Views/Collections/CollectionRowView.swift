// CollectionRowView.swift

import SwiftUI

// Importar el visor de cómics mejorado
import UIKit // Necesario para UIImage

struct CollectionRowView: View {
    let collection: Collection
    @ObservedObject var viewModel: CollectionsViewModel
    var onDelete: (() -> Void)?
    @State private var isShowingRenameAlert = false
    @State private var newName = ""
    
    var body: some View {
        NavigationLink(destination: CollectionDetailView(collection: collection, viewModel: viewModel)) {
            VStack(alignment: .leading, spacing: 8) {
                // Encabezado con título y menú
                HStack(alignment: .top) {
                    // Título e información
                    HStack(spacing: 8) {
                        Text(collection.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(collection.color)
                            .lineLimit(1)
                        
                        Text("\(viewModel.booksInCollection(collection).count) \(viewModel.booksInCollection(collection).count == 1 ? "libro" : "libros")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Menú
                    Menu {
                        Button(action: {
                            newName = collection.name
                            isShowingRenameAlert = true
                        }) {
                            Label("Renombrar", systemImage: "pencil")
                        }
                        
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
                .padding(.horizontal, 12)
                .padding(.top, 16)
                
                // Portadas alineadas horizontalmente
                AnimatedCoversView(books: viewModel.booksInCollection(collection))
                .padding(.top, 6)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                
                // Mostrar progreso general si hay libros
                if !viewModel.booksInCollection(collection).isEmpty {
                    let books = viewModel.booksInCollection(collection)
                    let averageProgress = books.reduce(0.0) { $0 + $1.book.progress } / Double(books.count)
                    
                    HStack(spacing: 8) {
                        ProgressBar(value: averageProgress, height: 5, color: collection.color)
                            .frame(height: 5)
                        
                        Text("\(Int(averageProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(collection.color)
                    }
                    .padding(.top, 0)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                } else {
                    Text("Añade libros a esta colección")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 0)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 0)
            .frame(height: 290)
            .background(
                ZStack {
                    // Fondo con blur al estilo Apple Books
                    if !viewModel.booksInCollection(collection).isEmpty, let firstBook = viewModel.booksInCollection(collection).first, let coverPath = firstBook.metadata.coverPath, let coverImage = UIImage(contentsOfFile: coverPath) {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 50)
                            .opacity(0.2)
                            .clipped()
                    }
                    
                    // Gradiente sobre el fondo
                    LinearGradient(
                        gradient: Gradient(colors: [
                            collection.color.opacity(0.15),
                            Color(.systemBackground).opacity(0.9)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .cornerRadius(12)
            .padding(.horizontal, 0)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Renombrar colección", isPresented: $isShowingRenameAlert) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) { }
            Button("Renombrar") {
                if !newName.isEmpty {
                    viewModel.renameCollection(collection, newName: newName)
                }
            }
        } message: {
            Text("Introduce el nuevo nombre para la colección")
        }
    }
}

// Vista de detalle de la colección
struct CollectionDetailView: View {
    let collection: Collection
    @ObservedObject var viewModel: CollectionsViewModel
    @State private var selectedBook: CompleteBook? = nil
    @State private var showingComicViewer = false
    @State private var animateTransition = false
    @State private var isDragging = false
    @State private var draggedBookIndex: Int? = nil
    @State private var dragCancellationTask: DispatchWorkItem?
    
    var books: [CompleteBook] {
        viewModel.booksInCollection(collection)
    }
    
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
                    
                    // Indicador de reordenamiento
                    if books.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 12))
                            Text("Arrastra para reordenar")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Grid de libros
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 20) {
                    ForEach(books) { book in
                        VStack(alignment: .leading, spacing: 8) {
                            // Portada del libro con gesto de toque
                            ZStack(alignment: .bottom) {
                                // Base: portada
                                bookCover(for: book)
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
                                
                                // Barra de progreso y etiquetas
                                if book.book.progress > 0 {
                                    VStack(spacing: 0) {
                                        Spacer()
                                        
                                        // Etiquetas antes de la barra
                                        HStack {
                                            // Fecha en la izquierda
                                            if let lastReadDate = book.book.lastReadDate {
                                                Text(formatLastReadDate(lastReadDate))
                                                    .font(.system(size: 8, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Color.black.opacity(0.4))
                                                    .cornerRadius(3)
                                            }
                                            
                                            Spacer()
                                            
                                            // Porcentaje en la derecha
                                            Text("\(Int(book.book.progress * 100))%")
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
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                // Fondo de la barra
                                                Rectangle()
                                                    .fill(Color.black.opacity(0.7))
                                                    .frame(height: 3)
                                                
                                                // Progreso
                                                Rectangle()
                                                    .fill(collection.color)
                                                    .frame(width: geometry.size.width * CGFloat(book.book.progress), height: 3)
                                            }
                                        }
                                        .frame(height: 3)
                                    }
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(2/3, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .onTapGesture {
                                if book.book.type == .cbz || book.book.type == .cbr {
                                    selectedBook = book
                                    
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        animateTransition = true
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        print("Abriendo cómic desde colección: \(book.displayTitle)")
                                        showingComicViewer = true
                                    }
                                } else {
                                    print("Abrir libro: \(book.displayTitle)")
                                }
                            }
                            .brightness(animateTransition && selectedBook?.id == book.id ? 0.1 : 0)
                            .opacity(isDragging ? (books.firstIndex(where: { $0.id == book.id }) == draggedBookIndex ? 1.0 : 0.6) : 1.0)
                            .scaleEffect(isDragging && books.firstIndex(where: { $0.id == book.id }) == draggedBookIndex ? 1.05 : 1.0)
                            .shadow(color: isDragging && books.firstIndex(where: { $0.id == book.id }) == draggedBookIndex ? Color.black.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
                            .overlay(
                                ZStack {
                                    if isDragging {
                                        if books.firstIndex(where: { $0.id == book.id }) == draggedBookIndex {
                                            // Estilo para el elemento que se está arrastrando
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(collection.color, lineWidth: 3)
                                            
                                            // Icono de mover
                                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(8)
                                                .background(collection.color)
                                                .clipShape(Circle())
                                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                        } else {
                                            // Indicador de destino potencial
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        }
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onDrag {
                                if let index = books.firstIndex(where: { $0.id == book.id }) {
                                    print("Iniciando arrastre de libro: \(book.displayTitle) [índice: \(index)]")
                                    withAnimation(.easeIn(duration: 0.2)) {
                                        isDragging = true
                                        draggedBookIndex = index
                                    }
                                    return NSItemProvider(object: "\(index)" as NSString)
                                }
                                return NSItemProvider()
                            }
                            .onDrop(of: [.text], delegate: BookDropDelegate(
                                book: book,
                                collection: collection,
                                viewModel: viewModel,
                                isDragging: $isDragging,
                                draggedBookIndex: $draggedBookIndex,
                                books: books
                            ))
                        
                            // Información del libro
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.displayTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                
                                Text(book.book.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .opacity(isDragging ? 0.7 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isDragging) { newValue in
            if !newValue {
                // Si termina el arrastre y no se procesó correctamente en el drop
                // programamos una limpieza del estado
                dragCancellationTask?.cancel()
                let task = DispatchWorkItem {
                    // Limpiar el estado completamente
                    draggedBookIndex = nil
                    print("Arrastre de libros cancelado/completado - estado limpiado")
                }
                dragCancellationTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
            }
        }
        .fullScreenCover(isPresented: $showingComicViewer, onDismiss: {
            withAnimation {
                animateTransition = false
            }
            
            // Asegurar que los libros se actualicen correctamente
            DispatchQueue.main.async {
                // Cargar libros disponibles para asegurar datos actualizados
                viewModel.loadAvailableBooks()
                
                // Verificar si el libro sigue en la colección después de actualizar
                // Esta es una solución simple pero efectiva
                if let updatedBookID = selectedBook?.id,
                   let collectionIndex = viewModel.collections.firstIndex(where: { $0.id == collection.id }),
                   !viewModel.collections[collectionIndex].books.contains(updatedBookID) {
                    
                    print("Libro desapareció de la colección, restaurando: \(selectedBook?.displayTitle ?? "Unknown")")
                    
                    // Restaurar el libro a la colección
                    var updatedCollection = collection
                    updatedCollection.books.append(updatedBookID)
                    viewModel.collections[collectionIndex] = updatedCollection
                    viewModel.saveCollections()
                }
                
                // Actualizar la UI
                viewModel.objectWillChange.send()
            }
        }) {
            if let book = selectedBook {
                EnhancedComicViewer(book: book, onProgressUpdate: { updatedBook in
                    print("Progreso actualizado desde colección: \(updatedBook.book.progress * 100)%")
                    
                    // Mantener una referencia al libro actualizado
                    selectedBook = updatedBook
                    
                    // Enviar notificación al HomeViewModel
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

// Delegado para manejar el drop de libros
struct BookDropDelegate: DropDelegate {
    let book: CompleteBook
    let collection: Collection
    let viewModel: CollectionsViewModel
    @Binding var isDragging: Bool
    @Binding var draggedBookIndex: Int?
    let books: [CompleteBook]
    
    func performDrop(info: DropInfo) -> Bool {
        // Verificar que tenemos índices válidos para realizar el cambio
        guard let draggedIndex = draggedBookIndex,
              draggedIndex < books.count,
              let targetIndex = books.firstIndex(where: { $0.id == book.id }) else {
            
            // Limpiar estado si no hay cambios válidos
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDragging = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    draggedBookIndex = nil
                }
            }
            print("Drop cancelado: índices inválidos")
            return false
        }
        
        // Si los índices son iguales, no hay nada que hacer
        if draggedIndex == targetIndex {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDragging = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    draggedBookIndex = nil
                }
            }
            print("Drop cancelado: mismo índice")
            return false
        }
        
        print("Realizando drop: moviendo libro de posición \(draggedIndex) a \(targetIndex)")
        
        DispatchQueue.main.async {
            // Crear una copia de los libros actuales y reordenarlos
            var updatedBooks = books
            let draggedBook = updatedBooks[draggedIndex]
            updatedBooks.remove(at: draggedIndex)
            updatedBooks.insert(draggedBook, at: targetIndex)
            
            print("Libros reordenados, actualizando colección: \(collection.name)")
            for (i, book) in updatedBooks.enumerated() {
                print("[\(i)] - \(book.displayTitle)")
            }
            
            // Actualizar el orden en el modelo
            viewModel.updateBooksOrder(in: collection, books: updatedBooks)
            
            // Limpiar estado
            withAnimation(.easeOut(duration: 0.2)) {
                isDragging = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                draggedBookIndex = nil
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // No realizamos actualizaciones en tiempo real para evitar parpadeos
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        // No hacemos nada para evitar parpadeos
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedIndex = draggedBookIndex,
              draggedIndex < books.count,
              let targetIndex = books.firstIndex(where: { $0.id == book.id }) else {
            return false
        }
        return true
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
        
        return CollectionRowView(collection: sampleCollection, viewModel: CollectionsViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 