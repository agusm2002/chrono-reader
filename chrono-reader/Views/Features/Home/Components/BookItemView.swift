import SwiftUI
import Combine
import CoreGraphics
import ImageIO

struct BookItemView: View {
    let book: CompleteBook
    var displayMode: DisplayMode = .grid
    var showTitle: Bool = true
    var onDelete: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    @State private var isShowingDeleteMenu = false
    @State private var isShowingComicViewer = false
    @State private var isShowingEPUBViewer = false
    @State private var isShowingAudioPlayer = false
    @State private var isShowingCoverFullScreen = false
    @State private var isShowingRenameAlert = false
    @State private var animateTransition = false
    @State private var newTitle = ""
    
    // Notificación para actualizar la UI cuando se cambie un título
    private let titleChangedNotification = NotificationCenter.default.publisher(for: Notification.Name("CustomTitleChanged"))

    enum DisplayMode {
        case grid, list, large, audioSquare
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Containment wrapper to prevent hitbox overflow
            ZStack {
                // Portada con overlays
                ZStack(alignment: .bottom) {
                    // Base: portada
                    bookCover
                    
                    // Capa 1: gradiente para mejorar legibilidad
                    gradientOverlay
                    
                    // Capa 2 y 3: Etiquetas y barra de progreso
                    if book.book.progress > 0 && displayMode != .list {
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
                            ZStack(alignment: .leading) {
                                // Fondo de la barra
                                Rectangle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(height: 3)
                                
                                // Progreso
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(Color.appTheme())
                                        .frame(width: geometry.size.width * CGFloat(book.book.progress))
                                }
                                .frame(height: 3)
                            }
                        }
                    }
                    
                    // Capa 4: Indicador de favorito
                    if book.book.isFavorite {
                        VStack(alignment: .trailing) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.yellow)
                                .padding(8)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(displayMode == .list ? nil : (displayMode == .audioSquare ? 1.0 : 0.68), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .scaleEffect(animateTransition ? 1.05 : 1.0)
                .brightness(animateTransition ? 0.1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    animateTransition = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    openBook()
                }
            }
            .onLongPressGesture {
                isShowingDeleteMenu = true
            }
            .contextMenu {
                Button(action: {
                    isShowingCoverFullScreen = true
                }) {
                    Label("Ver portada", systemImage: "photo")
                }
                
                Button(action: {
                    onToggleFavorite?()
                }) {
                    Label(book.book.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos", 
                          systemImage: book.book.isFavorite ? "star.fill" : "star")
                }
                
                Button(action: {
                    newTitle = book.displayTitle
                    isShowingRenameAlert = true
                }) {
                    Label("Renombrar título", systemImage: "pencil")
                }
                
                Button(action: {
                    onDelete?()
                }) {
                    Label("Eliminar", systemImage: "trash")
                }
            }
            .id(book.id) // Ensure each book has a unique identity
            
            if showTitle && displayMode != .large {
                // Espacio fijo para la info del libro
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.displayTitle)
                        .font(.system(size: displayMode == .large ? 15 : 13, weight: .medium))
                        .lineLimit(displayMode == .large ? 2 : 1)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        if let localURL = book.metadata.localURL,
                           let fileSize = try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 {
                            Text(formatFileSize(fileSize))
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(4)
                            
                            if let pageCount = book.book.pageCount, pageCount > 0 {
                                Text("\(pageCount) págs.")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            typeBadge
                            
                            if let issue = book.book.issueNumber {
                                Text("#\(issue)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        } else {
                            // Si no hay metadatos, mostramos espacios vacíos para mantener la altura
                            typeBadge
                        }
                    }
                }
                .frame(height: 40) // Altura fija para la información
            }
        }
        .frame(minHeight: displayMode == .list ? nil : (displayMode == .large ? 320 : (displayMode == .audioSquare ? (showTitle ? 250 : 220) : (showTitle ? 240 : 280))))
        .padding(.vertical, 4)
        // Comic Viewer
        .fullScreenCover(isPresented: $isShowingComicViewer, onDismiss: {
            withAnimation {
                animateTransition = false
            }
        }) {
            EnhancedComicViewer(book: book, onProgressUpdate: { updatedBook in
                print("BookItemView recibió actualización de progreso: \(updatedBook.book.progress * 100)%")
                
                NotificationCenter.default.post(
                    name: Notification.Name("BookProgressUpdated"),
                    object: nil,
                    userInfo: ["book": updatedBook]
                )
            })
            .transition(.opacity)
        }
        // EPUB Viewer
        .fullScreenCover(isPresented: $isShowingEPUBViewer, onDismiss: {
            withAnimation {
                animateTransition = false
            }
        }) {
            Group {
                if let url = book.metadata.localURL {
                    EPUBReaderContainer(url: url, isPresented: $isShowingEPUBViewer)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("No se encontró el archivo del libro")
                            .font(.title2)
                            .bold()
                        
                        Button("Cerrar") {
                            isShowingEPUBViewer = false
                        }
                        .padding()
                        .background(Color.appTheme())
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        // Audio Player
        .fullScreenCover(isPresented: $isShowingAudioPlayer, onDismiss: {
            withAnimation {
                animateTransition = false
            }
        }) {
            AudioPlayerView(book: book)
                .transition(.opacity)
        }
        // Visor de portada a pantalla completa
        .fullScreenCover(isPresented: $isShowingCoverFullScreen) {
            ZStack {
                // Fondo negro
                Color.black.ignoresSafeArea()
                
                // Contenido
                VStack {
                    // Encabezado con título y botón cerrar
                    HStack {
                        Text(book.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Spacer()
                        
                        Button(action: {
                            isShowingCoverFullScreen = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Portada centrada con carga optimizada
                    if let coverPath = book.metadata.coverPath {
                        // Utilizamos CachedImage para la carga optimizada
                        ZStack {
                            // Indicador de carga
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            // Imagen principal con renderizado asíncrono y caché
                            CachedImage(imagePath: coverPath, targetSize: CGSize(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.7))
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                        }
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 250, height: 350)
                            
                            VStack(spacing: 16) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Portada no disponible")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Información adicional
                    VStack(spacing: 8) {
                        Text(book.book.author)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            Text(book.book.type.rawValue.uppercased())
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            
                            if let pageCount = book.book.pageCount, pageCount > 0 {
                                Text("\(pageCount) páginas")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .statusBar(hidden: true)
            .preferredColorScheme(.dark)
        }
        // Alerta para confirmar eliminación
        .alert(isPresented: $isShowingDeleteMenu) {
            Alert(
                title: Text("Eliminar libro"),
                message: Text("¿Estás seguro de que quieres eliminar este libro?"),
                primaryButton: .destructive(Text("Eliminar")) {
                    onDelete?()
                },
                secondaryButton: .cancel()
            )
        }
        // Alerta para renombrar título
        .alert("Renombrar título", isPresented: $isShowingRenameAlert) {
            TextField("Título", text: $newTitle)
            Button("Cancelar", role: .cancel) { }
            Button("Guardar") {
                if !newTitle.isEmpty {
                    book.updateCustomTitle(newTitle)
                    // Notificar el cambio para actualizar la interfaz
                    NotificationCenter.default.post(
                        name: Notification.Name("CustomTitleChanged"),
                        object: nil,
                        userInfo: ["bookId": book.id]
                    )
                }
            }
        } message: {
            Text("Introduce el nuevo título para este libro")
        }
        .onReceive(titleChangedNotification) { notification in
            // Forzar actualización cuando cambie un título (para otros elementos de la UI)
            if let bookId = notification.userInfo?["bookId"] as? UUID, bookId == book.id {
                // Forzar actualización de la vista
                DispatchQueue.main.async {
                    // Este hack fuerza la actualización de la vista
                    withAnimation {
                        animateTransition = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateTransition = false
                        }
                    }
                }
            }
        }
    }

    private var bookCover: some View {
        Group {
            if let coverPath = book.metadata.coverPath {
                GeometryReader { geometry in
                    // Usar la nueva vista CachedImage que gestiona optimización y caché
                    CachedImage(imagePath: coverPath, targetSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                        // Aplicar modificadores específicos según el tipo de libro
                        .modifier(CoverLayoutModifier(bookType: book.book.type))
                }
            } else {
                ZStack {
                    Color(.systemGray5)
                    // Icono específico según el tipo de libro
                    Group {
                        if book.book.type == .m4b {
                            Image(systemName: "headphones.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        } else {
                            Image(systemName: "book.closed")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }
                    .allowsHitTesting(false)
                }
                // Aplicar modificadores específicos según el tipo de libro
                .modifier(CoverLayoutModifier(bookType: book.book.type))
            }
        }
    }

    // Modificador para adaptar la portada según el tipo de libro
    struct CoverLayoutModifier: ViewModifier {
        let bookType: BookType
        
        func body(content: Content) -> some View {
            if bookType == .m4b {
                // Para audiolibros, centrar la portada cuadrada y añadir un fondo
                content
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.1))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Para libros y cómics, mantener la proporción vertical
                content
            }
        }
    }

    private var gradientOverlay: some View {
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
    }

    private var progressPercentageOverlay: some View {
        EmptyView()
    }
    
    private func openBook() {
        switch book.book.type {
        case .cbz, .cbr:
            isShowingComicViewer = true
        case .epub:
            isShowingEPUBViewer = true
        case .m4b:
            isShowingAudioPlayer = true
        case .pdf:
            // Implementación futura para PDF
            break
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

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private var typeBadge: some View {
        Text(book.book.type.rawValue.uppercased())
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            .foregroundColor(.primary)
            .cornerRadius(4)
    }

    private var badgeColor: Color {
        switch book.book.type {
        case .epub: return Color(red: 0.3, green: 0.6, blue: 0.9)
        case .pdf: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .cbr, .cbz: return Color(red: 0.7, green: 0.4, blue: 0.9)
        case .m4b: return Color(red: 0.3, green: 0.8, blue: 0.5) // Color verde-azulado para audiolibros
        }
    }

    private var favoriteIndicator: some View {
        EmptyView()
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

struct EPUBReaderContainer: View {
    let url: URL
    @Binding var isPresented: Bool
    @State private var epubBook: EPUBBook?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando libro...")
            } else if let error = error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error al cargar el libro")
                        .font(.title2)
                        .bold()
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Cerrar") {
                        isPresented = false
                    }
                    .padding()
                    .background(Color.appTheme())
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            } else if let epubBook = epubBook {
                EPUBBasicReaderView(document: epubBook)
                    .transition(.opacity)
            }
        }
        .onAppear {
            loadBook()
        }
    }
    
    private func loadBook() {
        Task {
            do {
                let book = try await EPUBService.parseEPUB(at: url)
                await MainActor.run {
                    self.epubBook = book
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
