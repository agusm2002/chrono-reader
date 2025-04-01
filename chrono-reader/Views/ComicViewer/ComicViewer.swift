import SwiftUI
import ZIPFoundation
import Unrar

struct ComicViewer: View {
    let book: CompleteBook
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 0
    @State private var pages: [UIImage] = []
    @State private var isLoading: Bool = true
    @State private var isFocusMode: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartX: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var updatedBook: CompleteBook
    @Environment(\.presentationMode) var presentationMode
    
    // Callback para actualizar el progreso en HomeView
    var onProgressUpdate: ((CompleteBook) -> Void)?
    
    init(book: CompleteBook, onProgressUpdate: ((CompleteBook) -> Void)? = nil) {
        self.book = book
        self.onProgressUpdate = onProgressUpdate
        // Inicializar el estado con el libro actual
        self._updatedBook = State(initialValue: book)
        
        print("Inicializando ComicViewer para: \(book.displayTitle)")
        print("Progreso guardado: \(book.book.progress * 100)%")
        if let lastReadDate = book.book.lastReadDate {
            print("Última lectura: \(lastReadDate)")
        }
        
        // No establecer la página inicial aquí, se hará después de cargar las páginas
        // en la función loadComicPages
    }
    
    var body: some View {
        ZStack {
            // Fondo negro
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if !pages.isEmpty {
                pageView
            } else {
                errorView
            }
            
            // Overlay de información
            if !isFocusMode {
                VStack {
                    // Barra superior
                    topBar
                    
                    Spacer()
                    
                    // Barra inferior
                    bottomBar
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isFocusMode)
            }
        }
        .statusBar(hidden: isFocusMode)
        .onTapGesture {
            withAnimation {
                isFocusMode.toggle()
            }
        }
        .onAppear {
            print("ComicViewer apareciendo - cargando páginas")
            loadComicPages()
        }
        .onDisappear {
            print("ComicViewer desapareciendo - guardando progreso final")
            // Asegurarse de que el progreso se guarde al cerrar el visor
            if !isLoading && totalPages > 0 {
                saveReadingProgress()
                
                // Llamar al callback para actualizar el progreso en HomeView
                if let finalBook = createUpdatedBook() {
                    onProgressUpdate?(finalBook)
                }
            }
        }
    }
    
    // Vista de carga
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Cargando cómic...")
                .foregroundColor(.white)
                .font(.headline)
                .padding(.top, 20)
        }
    }
    
    // Vista de error
    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.white)
            
            Text("No se pudieron cargar las páginas del cómic")
                .foregroundColor(.white)
                .font(.headline)
                .padding(.top, 20)
        }
    }
    
    // Vista de la página actual
    private var pageView: some View {
        GeometryReader { geometry in
            ZStack {
                // Página actual
                Image(uiImage: pages[currentPage])
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(x: offset.width + dragOffset, y: offset.height)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Página anterior (visible durante el deslizamiento)
                if currentPage > 0 && dragOffset > 0 {
                    Image(uiImage: pages[currentPage - 1])
                        .resizable()
                        .scaledToFit()
                        .offset(x: -geometry.size.width + dragOffset)
                        .opacity(min(1.0, dragOffset / (geometry.size.width * 0.5)))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                // Página siguiente (visible durante el deslizamiento)
                if currentPage < totalPages - 1 && dragOffset < 0 {
                    Image(uiImage: pages[currentPage + 1])
                        .resizable()
                        .scaledToFit()
                        .offset(x: geometry.size.width + dragOffset)
                        .opacity(min(1.0, -dragOffset / (geometry.size.width * 0.5)))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1.0 {
                            // Si está ampliado, permitir desplazamiento en todas direcciones
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        } else {
                            // Si no está ampliado, solo permitir desplazamiento horizontal para cambiar de página
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if scale > 1.0 {
                            // Si está ampliado, actualizar la posición final
                            lastOffset = offset
                        } else {
                            // Si no está ampliado, cambiar de página si el desplazamiento es suficiente
                            let threshold = geometry.size.width * 0.2
                            withAnimation(.easeOut(duration: 0.3)) {
                                if value.translation.width > threshold && currentPage > 0 {
                                    // Deslizar a la derecha (página anterior)
                                    currentPage -= 1
                                } else if value.translation.width < -threshold && currentPage < totalPages - 1 {
                                    // Deslizar a la izquierda (página siguiente)
                                    currentPage += 1
                                }
                                dragOffset = 0
                            }
                        }
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), 3.0) // Limitar el zoom entre 1x y 3x
                    }
                    .onEnded { value in
                        lastScale = scale
                        
                        // Si el zoom vuelve a 1, resetear el offset
                        if scale <= 1.0 {
                            withAnimation {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                // Doble toque para hacer zoom
                withAnimation {
                    if scale > 1.0 {
                        // Si ya está ampliado, volver al tamaño normal
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        // Ampliar al 2x
                        scale = 2.0
                        lastScale = 2.0
                    }
                }
            }
        }
        .onChange(of: currentPage) { _ in
            // Resetear el zoom y offset cuando cambia la página
            withAnimation {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
            
            // Guardar el progreso cuando cambia la página
            saveReadingProgress()
        }
    }
    
    // Barra superior
    private var topBar: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            
            Spacer()
            
            Text(book.displayTitle)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black, radius: 2, x: 0, y: 1)
            
            Spacer()
            
            Button(action: {
                // Acción para compartir o más opciones
            }) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // Barra inferior
    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Información de página
            HStack {
                Text("\(currentPage + 1) de \(totalPages)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                
                Spacer()
                
                if let series = book.book.series {
                    Text(series)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                    
                    if let issue = book.book.issueNumber {
                        Text("#\(issue)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Barra de progreso
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Barra de fondo
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Barra de progreso
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * CGFloat(currentPage + 1) / CGFloat(totalPages), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Controles de navegación
            HStack(spacing: 40) {
                Button(action: {
                    if currentPage > 0 {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(currentPage <= 0)
                .opacity(currentPage <= 0 ? 0.5 : 1.0)
                
                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(currentPage >= totalPages - 1)
                .opacity(currentPage >= totalPages - 1 ? 0.5 : 1.0)
            }
            .padding(.bottom, 20)
        }
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // Función para cargar las páginas del cómic
    private func loadComicPages() {
        guard let url = book.metadata.localURL else {
            print("Error: URL local no disponible")
            isLoading = false
            return
        }
        
        print("Cargando cómic desde: \(url.path)")
        print("Tipo de archivo: \(book.book.type.rawValue)")
        print("Progreso guardado: \(book.book.progress * 100)%")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Usar el ArchiveHelper para cargar las imágenes según el tipo de archivo
            print("Iniciando carga de imágenes con ArchiveHelper")
            let loadedPages = ArchiveHelper.loadImages(from: url, type: book.book.type)
            
            DispatchQueue.main.async {
                print("Carga de imágenes completada. Total: \(loadedPages.count)")
                self.pages = loadedPages
                self.totalPages = loadedPages.count
                
                print("Total de páginas cargadas: \(self.totalPages)")
                
                // Actualizar el libro con el recuento de páginas
                var updatedBookCopy = self.book.book
                updatedBookCopy.pageCount = loadedPages.count
                
                // Crear una nueva instancia de CompleteBook con los metadatos actualizados
                self.updatedBook = CompleteBook(
                    id: book.id,
                    title: updatedBookCopy.title,
                    author: updatedBookCopy.author,
                    coverImage: updatedBookCopy.coverImage,
                    type: updatedBookCopy.type,
                    progress: updatedBookCopy.progress,
                    localURL: self.book.metadata.localURL,
                    cover: book.getCoverImage(), // Mantener la portada existente
                    lastReadDate: updatedBookCopy.lastReadDate // Mantener la fecha de última lectura
                )
                
                // Establecer la página inicial basada en el progreso guardado
                if self.book.book.progress > 0 && self.totalPages > 0 {
                    // Calcular la página basada en el progreso
                    let calculatedPage = Int(Double(self.totalPages - 1) * self.book.book.progress)
                    // Asegurarse de que la página esté dentro de los límites válidos
                    self.currentPage = max(0, min(calculatedPage, self.totalPages - 1))
                    print("Restaurando a la página \(self.currentPage + 1) de \(self.totalPages) (progreso: \(self.book.book.progress * 100)%)")
                } else {
                    print("No hay progreso guardado, comenzando desde la página 1")
                    self.currentPage = 0
                }
                
                self.isLoading = false
                
                // Notificar que el cómic se ha cargado correctamente
                print("Cómic cargado correctamente: \(self.book.displayTitle)")
            }
        }
    }
    
    // Función para guardar el progreso de lectura
    private func saveReadingProgress() {
        guard totalPages > 0 else { 
            print("No se puede guardar el progreso: totalPages = 0")
            return 
        }
        
        // Calcular el progreso como un valor entre 0 y 1
        // Para evitar división por cero y asegurar que el progreso esté entre 0 y 1
        let progress: Double
        if totalPages <= 1 {
            progress = currentPage > 0 ? 1.0 : 0.0
        } else {
            progress = Double(currentPage) / Double(totalPages - 1)
        }
        
        // Asegurarse de que el progreso esté entre 0 y 1
        let clampedProgress = max(0.0, min(1.0, progress))
        
        print("Guardando progreso: página \(currentPage + 1) de \(totalPages) = \(clampedProgress * 100)%")
        
        // Crear una copia del libro con el progreso actualizado
        var bookCopy = book.book
        bookCopy.progress = clampedProgress
        bookCopy.lastReadDate = Date()
        bookCopy.pageCount = totalPages
        
        // Crear la versión final del libro con todos los metadatos actualizados
        let finalUpdatedBook = CompleteBook(
            id: book.id,
            title: bookCopy.title,
            author: bookCopy.author,
            coverImage: bookCopy.coverImage,
            type: bookCopy.type,
            progress: clampedProgress,
            localURL: book.metadata.localURL,
            cover: book.getCoverImage(),
            lastReadDate: bookCopy.lastReadDate
        )
        
        // Actualizar el estado local
        self.updatedBook = finalUpdatedBook
        
        // Notificar a la aplicación sobre el cambio en el progreso
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("BookProgressUpdated"),
                object: nil,
                userInfo: ["book": finalUpdatedBook]
            )
            
            print("Notificación de progreso enviada: \(clampedProgress * 100)% para \(finalUpdatedBook.displayTitle)")
        }
    }
    
    // Función auxiliar para crear un libro actualizado
    private func createUpdatedBook() -> CompleteBook? {
        guard totalPages > 0 else { return nil }
        
        // Calcular el progreso como un valor entre 0 y 1
        let progress: Double
        if totalPages <= 1 {
            progress = currentPage > 0 ? 1.0 : 0.0
        } else {
            progress = Double(currentPage) / Double(totalPages - 1)
        }
        
        // Asegurarse de que el progreso esté entre 0 y 1
        let clampedProgress = max(0.0, min(1.0, progress))
        
        // Crear una copia del libro con el progreso actualizado
        var bookCopy = book.book
        bookCopy.progress = clampedProgress
        bookCopy.lastReadDate = Date()
        bookCopy.pageCount = totalPages
        
        // Crear la versión final del libro con todos los metadatos actualizados
        return CompleteBook(
            id: book.id,
            title: bookCopy.title,
            author: bookCopy.author,
            coverImage: bookCopy.coverImage,
            type: bookCopy.type,
            progress: clampedProgress,
            localURL: book.metadata.localURL,
            cover: book.getCoverImage(),
            lastReadDate: bookCopy.lastReadDate
        )
    }
}

// Vista previa
struct ComicViewer_Previews: PreviewProvider {
    static var previews: some View {
        ComicViewer(book: CompleteBook.init(
            title: "Spider-Man: No Way Home",
            author: "Marvel Comics",
            coverImage: "comic1",
            type: .cbz,
            progress: 0.5
        ))
    }
}
