import SwiftUI
import ZIPFoundation

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
    
    init(book: CompleteBook) {
        self.book = book
        // Inicializar el estado con el libro actual
        self._updatedBook = State(initialValue: book)
        
        // Inicializar la página actual basada en el progreso guardado
        if book.book.progress > 0 && book.book.pageCount != nil {
            let initialPage = Int(Double(book.book.pageCount!) * book.book.progress)
            self._currentPage = State(initialValue: max(0, min(initialPage, (book.book.pageCount ?? 1) - 1)))
        }
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
            loadComicPages()
        }
        .onDisappear {
            saveReadingProgress()
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
            
            Text(book.book.title)
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
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var loadedPages: [UIImage] = []
            
            switch book.book.type {
            case .cbz:
                loadedPages = loadCBZPages(from: url)
            case .cbr:
                loadedPages = loadCBRPages(from: url)
            default:
                break
            }
            
            // Ordenar las páginas por nombre de archivo
            loadedPages.sort { (_, _) in
                // Aquí se implementaría la lógica de ordenación si es necesario
                return true
            }
            
            DispatchQueue.main.async {
                self.pages = loadedPages
                self.totalPages = loadedPages.count
                
                // Actualizar el libro con el recuento de páginas
                // Crear una nueva instancia de Book con el pageCount actualizado
                var updatedBookCopy = self.book.book
                updatedBookCopy.pageCount = loadedPages.count
                
                // Crear una nueva instancia de CompleteBook con el ID y la ruta de la portada preservados
                self.updatedBook = CompleteBook(
                    id: book.id,
                    title: updatedBookCopy.title,
                    author: updatedBookCopy.author,
                    coverImage: updatedBookCopy.coverImage,
                    type: updatedBookCopy.type,
                    progress: updatedBookCopy.progress,
                    localURL: self.book.metadata.localURL
                )
                
                self.isLoading = false
            }
        }
    }
    
    // Función para guardar el progreso de lectura
    private func saveReadingProgress() {
        guard totalPages > 0 else { return }
        
        // Calcular el progreso como un valor entre 0 y 1
        let progress = Double(currentPage + 1) / Double(totalPages)
        
        // Crear una nueva instancia de CompleteBook con el ID y la ruta de la portada preservados
        self.updatedBook = CompleteBook(
            id: book.id,
            title: book.book.title,
            author: book.book.author,
            coverImage: book.book.coverImage,
            type: book.book.type,
            progress: progress,
            localURL: book.metadata.localURL
        )
        
        // Notificar a la aplicación sobre el cambio en el progreso
        NotificationCenter.default.post(
            name: Notification.Name("BookProgressUpdated"),
            object: nil,
            userInfo: ["book": updatedBook]
        )
    }
    
    // Función para cargar páginas de un archivo CBZ
    private func loadCBZPages(from url: URL) -> [UIImage] {
        var images: [UIImage] = []
        
        guard let archive = Archive(url: url, accessMode: .read) else {
            return images
        }
        
        let imageExtensions = ["jpg", "jpeg", "png", "gif"]
        
        for entry in archive.sorted(by: { $0.path < $1.path }) {
            let pathExtension = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
            
            if imageExtensions.contains(pathExtension) {
                do {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try archive.extract(entry, to: tempURL)
                    
                    if let imageData = try? Data(contentsOf: tempURL),
                       let image = UIImage(data: imageData) {
                        images.append(image)
                    }
                    
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {
                    print("Error extracting \(entry.path): \(error)")
                }
            }
        }
        
        return images
    }
    
    // Función para cargar páginas de un archivo CBR
    private func loadCBRPages(from url: URL) -> [UIImage] {
        // La implementación para CBR requeriría una biblioteca adicional para manejar archivos RAR
        // Por ahora, devolvemos un array vacío
        return []
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
