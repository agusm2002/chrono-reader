import SwiftUI
import UIKit
import Combine

// MARK: - Enumeraciones y Constantes

enum ReadingMode: String, CaseIterable, Identifiable {
    case PAGED_MANGA = "Manga (RTL)"
    case PAGED_COMIC = "Cómic (LTR)"
    case VERTICAL = "Vertical (Webtoon)"
    
    var id: String { self.rawValue }
    
    var isVertical: Bool {
        return self == .VERTICAL
    }
    
    var isInverted: Bool {
        return self == .PAGED_MANGA
    }
}

// MARK: - Modelo de Datos para el Visor

// Añadir esta estructura para representar una página unida en el modo webtoon
struct WebtoonPage: Identifiable {
    var id = UUID()
    var image: UIImage
}

// Añadir esta estructura para representar una página doble
struct DoublePage: Identifiable {
    var id = UUID()
    var leftImage: UIImage
    var rightImage: UIImage?
}

class ComicViewerModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var pages: [UIImage] = []
    @Published var isLoading: Bool = true
    @Published var readingMode: ReadingMode = .PAGED_COMIC
    @Published var showControls: Bool = true
    @Published var showSettings: Bool = false
    @Published var scale: CGFloat = 1.0
    @Published var doublePaged: Bool = false
    @Published var useWhiteBackground: Bool = false
    @Published var lastPageOffsetPCT: Double? = nil
    @Published var pendingInitialScroll: Bool = false
    @Published var isDraggingProgress: Bool = false
    @Published var targetPage: Int? = nil
    @Published var lastDraggedPage: Int? = nil
    @Published var showThumbnails: Bool = true
    @Published var webtoonScrollOffset: CGFloat = 0
    @Published var webtoonPages: [WebtoonPage] = []
    @Published var doublePages: [DoublePage] = []
    @Published var isolateFirstPage: Bool = true
    
    let book: CompleteBook
    
    init(book: CompleteBook) {
        self.book = book
        print("Inicializando ComicViewerModel para: \(book.displayTitle)")
    }
    
    func loadPages() {
        guard let url = book.metadata.localURL else {
            print("Error: URL local no disponible")
            isLoading = false
            return
        }
        
        print("Cargando cómic desde: \(url.path)")
        
        // Marcamos que estamos cargando
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let loadedPages = ArchiveHelper.loadImages(from: url, type: self.book.book.type)
            
            DispatchQueue.main.async {
                self.pages = loadedPages
                self.totalPages = loadedPages.count
                
                // Crear webtoonPages a partir de las páginas cargadas
                self.webtoonPages = self.pages.map { WebtoonPage(image: $0) }
                
                // Establecer la página inicial basada en el progreso guardado
                if self.book.book.progress > 0 && self.totalPages > 0 {
                    let calculatedPage = Int(Double(self.totalPages - 1) * self.book.book.progress)
                    self.currentPage = max(0, min(calculatedPage, self.totalPages - 1))
                    
                    // Si es un webtoon, restaurar la posición vertical dentro de la página
                    if self.readingMode.isVertical {
                        // Recuperar la posición vertical guardada del libro
                        if let savedOffset = self.book.lastPageOffsetPCT {
                            self.lastPageOffsetPCT = savedOffset
                            print("Restaurando posición vertical: \(savedOffset * 100)%")
                        } else {
                            // Si no hay posición guardada, usar 0.0 como valor predeterminado
                            self.lastPageOffsetPCT = 0.0
                        }
                    }
                    
                    // Marcar que hay un desplazamiento inicial pendiente
                    self.pendingInitialScroll = true
                    
                    print("Restaurando a la página \(self.currentPage + 1) de \(self.totalPages)")
                }
                
                // Diferir la construcción de páginas dobles al siguiente ciclo de actualización
                if self.doublePaged && !self.readingMode.isVertical {
                    DispatchQueue.main.async {
                        self.buildDoublePages()
                        // Asegurarnos de que la vista se actualice después de construir las páginas dobles
                        DispatchQueue.main.async {
                            self.isLoading = false
                        }
                    }
                } else {
                    self.isLoading = false
                }
            }
        }
    }
    
    func saveProgress() -> CompleteBook? {
        guard totalPages > 0 else { return nil }
        
        // Calcular el progreso como un valor entre 0 y 1
        let progress: Double
        if readingMode.isVertical {
            // En modo webtoon, usamos directamente el valor de lastPageOffsetPCT
            // que se actualiza continuamente durante el desplazamiento
            progress = lastPageOffsetPCT ?? 0.0
        } else {
            // En modo paginado (cómic o manga)
            if totalPages <= 1 {
                progress = currentPage > 0 ? 1.0 : 0.0
            } else {
                progress = Double(currentPage) / Double(totalPages - 1)
            }
        }
        
        // Asegurarse de que el progreso esté entre 0 y 1
        let clampedProgress = max(0.0, min(1.0, progress))
        
        print("Guardando progreso: página \(currentPage + 1) de \(totalPages) = \(clampedProgress * 100)%")
        if let offset = lastPageOffsetPCT {
            print("Posición dentro de la página: \(offset * 100)%")
        }
        
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
            lastReadDate: bookCopy.lastReadDate,
            lastPageOffsetPCT: readingMode.isVertical ? lastPageOffsetPCT : nil
        )
    }
    
    // Método para construir las páginas dobles
    func buildDoublePages() {
        guard !pages.isEmpty, !readingMode.isVertical else {
            // Actualizar inmediatamente para evitar retrasos en la UI
            doublePages = []
            return
        }
        
        print("Reconstruyendo páginas dobles con opción de combinar portada: \(isolateFirstPage)")
        
        // Trabajar con copias locales para evitar problemas de concurrencia
        let localPages = pages
        let localReadingMode = readingMode
        let localIsolateFirstPage = isolateFirstPage
        
        // Crear una lista de resultados
        var result: [DoublePage] = []
        var currentIndex = 0
        
        // Decidir orden según la dirección de lectura
        let isRightToLeft = localReadingMode == .PAGED_MANGA
        
        // Opciones para determinar si una página es ancha (doble)
        func isWidePage(_ image: UIImage) -> Bool {
            return image.size.width > image.size.height
        }
        
        // Si la primera página debe estar aislada (ahora cuando isolateFirstPage es false)
        // y hay suficientes páginas
        if !localIsolateFirstPage && currentIndex < localPages.count {
            print("Aislando la primera página (portada)")
            let singlePage = localPages[currentIndex]
            result.append(DoublePage(
                id: UUID(),
                leftImage: singlePage,
                rightImage: nil
            ))
            currentIndex += 1
        } else {
            print("Combinando la primera página con otras")
        }
        
        // Procesar el resto de páginas
        while currentIndex < localPages.count {
            let currentPage = localPages[currentIndex]
            
            // Si es una página ancha, mostrarla sola
            if isWidePage(currentPage) {
                result.append(DoublePage(
                    id: UUID(),
                    leftImage: currentPage,
                    rightImage: nil
                ))
                currentIndex += 1
                continue
            }
            
            // Si es la última página, mostrarla sola
            if currentIndex == localPages.count - 1 {
                result.append(DoublePage(
                    id: UUID(),
                    leftImage: currentPage,
                    rightImage: nil
                ))
                currentIndex += 1
                continue
            }
            
            // Combinar esta página con la siguiente
            let nextPage = localPages[currentIndex + 1]
            
            // Si la siguiente página es ancha, mostrar la actual sola
            if isWidePage(nextPage) {
                result.append(DoublePage(
                    id: UUID(),
                    leftImage: currentPage,
                    rightImage: nil
                ))
                currentIndex += 1
                continue
            }
            
            // Combinar las dos páginas según la dirección de lectura
            if isRightToLeft {
                // En manga (RTL), la página más avanzada va a la izquierda (es decir, la que tiene índice menor)
                result.append(DoublePage(
                    id: UUID(),
                    leftImage: currentPage,
                    rightImage: nextPage
                ))
            } else {
                // En cómic (LTR), la página más avanzada va a la derecha
                result.append(DoublePage(
                    id: UUID(),
                    leftImage: currentPage,
                    rightImage: nextPage
                ))
            }
            
            // Avanzar dos páginas
            currentIndex += 2
        }
        
        print("Reconstrucción completada: \(result.count) páginas dobles generadas")
        
        // Actualizar el modelo directamente en el hilo principal para inmediatez
        // Nota: Este cambio puede afectar la visualización actual y requerir un desplazamiento manual
        // a la página correcta después de la reconstrucción
        doublePages = result
    }
    
    func nextPage() {
        if readingMode == .PAGED_MANGA {
            // En modo manga, "siguiente" es ir a la izquierda (página anterior en términos de índice)
            if currentPage > 0 {
                if doublePaged {
                    // En modo de página doble, avanzamos de 2 en 2 (o 1 si es necesario)
                    let targetIndex = getNextPageIndex(from: currentPage, direction: -1)
                    currentPage = targetIndex
                } else {
                    currentPage -= 1
                }
            }
        } else {
            // En modo normal, "siguiente" es ir a la derecha (página siguiente en términos de índice)
            if currentPage < totalPages - 1 {
                if doublePaged {
                    // En modo de página doble, avanzamos de 2 en 2 (o 1 si es necesario)
                    let targetIndex = getNextPageIndex(from: currentPage, direction: 1)
                    currentPage = targetIndex
                } else {
                    currentPage += 1
                }
            }
        }
    }
    
    func previousPage() {
        if readingMode == .PAGED_MANGA {
            // En modo manga, "anterior" es ir a la derecha (página siguiente en términos de índice)
            if currentPage < totalPages - 1 {
                if doublePaged {
                    // En modo de página doble, avanzamos de 2 en 2 (o 1 si es necesario)
                    let targetIndex = getNextPageIndex(from: currentPage, direction: 1)
                    currentPage = targetIndex
                } else {
                    currentPage += 1
                }
            }
        } else {
            // En modo normal, "anterior" es ir a la izquierda (página anterior en términos de índice)
            if currentPage > 0 {
                if doublePaged {
                    // En modo de página doble, avanzamos de 2 en 2 (o 1 si es necesario)
                    let targetIndex = getNextPageIndex(from: currentPage, direction: -1)
                    currentPage = targetIndex
                } else {
                    currentPage -= 1
                }
            }
        }
    }
    
    // Función auxiliar para determinar el siguiente índice de página en modo doble
    private func getNextPageIndex(from currentIndex: Int, direction: Int) -> Int {
        // Mapear la página actual a un índice en doublePages
        var doublePageIndex = 0
        var pageInDoublePage = 0
        
        // Encontrar en qué página doble estamos
        for (i, doublePage) in doublePages.enumerated() {
            if doublePage.rightImage == nil {
                // Si es una página simple
                if pageToGlobalIndex(doublePageIndex: i, pageInDoublePage: 0) == currentIndex {
                    doublePageIndex = i
                    pageInDoublePage = 0
                    break
                }
            } else {
                // Si es una página doble
                if pageToGlobalIndex(doublePageIndex: i, pageInDoublePage: 0) == currentIndex {
                    doublePageIndex = i
                    pageInDoublePage = 0
                    break
                } else if pageToGlobalIndex(doublePageIndex: i, pageInDoublePage: 1) == currentIndex {
                    doublePageIndex = i
                    pageInDoublePage = 1
                    break
                }
            }
        }
        
        // Determinar el índice objetivo
        let targetDoublePageIndex: Int
        
        if direction > 0 {
            // Avanzar hacia adelante
            if doublePages[doublePageIndex].rightImage == nil || pageInDoublePage == 1 {
                // Si es una página simple o ya estamos en la página derecha, avanzar a la siguiente página doble
                targetDoublePageIndex = min(doublePageIndex + 1, doublePages.count - 1)
                return pageToGlobalIndex(doublePageIndex: targetDoublePageIndex, pageInDoublePage: 0)
            } else {
                // Si estamos en la página izquierda de una página doble, avanzar a la página derecha
                return pageToGlobalIndex(doublePageIndex: doublePageIndex, pageInDoublePage: 1)
            }
        } else {
            // Retroceder
            if doublePages[doublePageIndex].rightImage == nil || pageInDoublePage == 0 {
                // Si es una página simple o ya estamos en la página izquierda, retroceder a la página doble anterior
                targetDoublePageIndex = max(doublePageIndex - 1, 0)
                
                // Si la página a la que vamos es doble, ir a la página derecha, si no, ir a la única
                if doublePages[targetDoublePageIndex].rightImage != nil {
                    return pageToGlobalIndex(doublePageIndex: targetDoublePageIndex, pageInDoublePage: 1)
                } else {
                    return pageToGlobalIndex(doublePageIndex: targetDoublePageIndex, pageInDoublePage: 0)
                }
            } else {
                // Si estamos en la página derecha de una página doble, retroceder a la página izquierda
                return pageToGlobalIndex(doublePageIndex: doublePageIndex, pageInDoublePage: 0)
            }
        }
    }
    
    // Función para convertir de índices de página doble a índice global
    func pageToGlobalIndex(doublePageIndex: Int, pageInDoublePage: Int) -> Int {
        guard doublePageIndex < doublePages.count else { return 0 }
        
        var globalIndex = 0
        
        for i in 0..<doublePageIndex {
            if doublePages[i].rightImage == nil {
                globalIndex += 1 // Una página simple
            } else {
                globalIndex += 2 // Una página doble
            }
        }
        
        // Agregar la posición dentro de la página doble actual
        if pageInDoublePage == 1 && doublePages[doublePageIndex].rightImage != nil {
            globalIndex += 1
        }
        
        return globalIndex
    }
}

// MARK: - Vista Principal del Visor de Cómics

struct EnhancedComicViewer: View {
    @StateObject private var model: ComicViewerModel
    @Environment(\.presentationMode) var presentationMode
    var onProgressUpdate: ((CompleteBook) -> Void)?
    
    init(book: CompleteBook, onProgressUpdate: ((CompleteBook) -> Void)? = nil) {
        self._model = StateObject(wrappedValue: ComicViewerModel(book: book))
        self.onProgressUpdate = onProgressUpdate
    }
    
    var body: some View {
        ZStack {
            // Fondo negro o blanco según la configuración
            (model.useWhiteBackground ? Color.white : Color.black)
                .edgesIgnoringSafeArea(.all)
            
            if model.isLoading {
                loadingView
            } else if !model.pages.isEmpty {
                if model.readingMode.isVertical {
                    // Usar la vista Webtoon para el modo vertical
                    WebtoonViewerView(model: model)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    // Usar el visor paginado para los modos horizontales (comic/manga)
                    ComicViewerContainer(model: model)
                        .edgesIgnoringSafeArea(.all)
                }
            } else {
                errorView
            }
            
            // Overlay de controles
            if model.showControls {
                VStack(spacing: 0) {
                    topBar
                        .padding(.top, 5)
                    Spacer()
                    if !model.readingMode.isVertical {
                        // Solo mostrar la barra inferior en modos de lectura paginados
                        bottomBar
                            .padding(.bottom, 0)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: model.showControls)
                .edgesIgnoringSafeArea(.all)
            }
            
            // Ventana de configuración
            if model.showSettings {
                ComicSettingsView(
                    readingMode: $model.readingMode,
                    doublePaged: $model.doublePaged,
                    isolateFirstPage: $model.isolateFirstPage,
                    useWhiteBackground: $model.useWhiteBackground,
                    showThumbnails: $model.showThumbnails,
                    isPresented: $model.showSettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .statusBar(hidden: true)
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.all)
        .persistentSystemOverlaysSupressed(showControls: model.showControls)
        .onTapGesture {
            withAnimation {
                model.showControls.toggle()
            }
        }
        .onAppear {
            model.loadPages()
        }
        .onDisappear {
            if !model.isLoading && model.totalPages > 0 {
                if let updatedBook = model.saveProgress() {
                    // Usar DispatchQueue.main para asegurar que la notificación se envíe en el hilo principal
                    DispatchQueue.main.async {
                        // Primero llamar al callback si existe
                        onProgressUpdate?(updatedBook)
                        
                        // Luego enviar la notificación
                        NotificationCenter.default.post(
                            name: Notification.Name("BookProgressUpdated"),
                            object: nil,
                            userInfo: ["book": updatedBook]
                        )
                    }
                }
            }
        }
    }
    
    // Vista de carga
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: model.useWhiteBackground ? .black : .white))
                .scaleEffect(1.5)
            
            Text("Cargando cómic...")
                .foregroundColor(model.useWhiteBackground ? .black : .white)
                .font(.headline)
                .padding(.top, 20)
        }
    }
    
    // Vista de error
    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(model.useWhiteBackground ? .black : .white)
            
            Text("No se pudieron cargar las páginas del cómic")
                .foregroundColor(model.useWhiteBackground ? .black : .white)
                .font(.headline)
                .padding(.top, 20)
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
                    .foregroundColor(model.useWhiteBackground ? .black : .white)
                    .padding(12)
                    .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            
            Spacer()
            
            Text(model.book.displayTitle)
                .font(.headline)
                .foregroundColor(model.useWhiteBackground ? .black : .white)
                .lineLimit(1)
                .shadow(color: model.useWhiteBackground ? .clear : .black, radius: 2, x: 0, y: 1)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    model.showSettings = true
                }
            }) {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(model.useWhiteBackground ? .black : .white)
                    .padding(12)
                    .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 50)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    model.useWhiteBackground ? Color.white.opacity(0.7) : Color.black.opacity(0.7),
                    model.useWhiteBackground ? Color.white.opacity(0) : Color.black.opacity(0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // Barra inferior
    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            // Fondo con gradiente
            LinearGradient(
                gradient: Gradient(colors: [
                    model.useWhiteBackground ? Color.white.opacity(0) : Color.black.opacity(0), 
                    model.useWhiteBackground ? Color.white.opacity(0.7) : Color.black.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 5) {
                Spacer() // Empujar todo hacia abajo
                
                // Barra de progreso
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Barra de fondo
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(model.useWhiteBackground ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
                            .frame(height: 3)
                            .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 1, x: 0, y: 0)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Marcar que estamos arrastrando
                                        model.isDraggingProgress = true
                                        
                                        // Calcular la posición relativa del toque en la barra
                                        let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                        
                                        // Calcular la página correspondiente
                                        let newPage = Int(round(percentage * CGFloat(model.totalPages - 1)))
                                        
                                        // Almacenar la página objetivo durante el arrastre
                                        model.targetPage = max(0, min(newPage, model.totalPages - 1))
                                        
                                        // Generar feedback háptico cuando cambia de página durante el arrastre
                                        if model.lastDraggedPage != model.targetPage {
                                            let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
                                            feedbackGenerator.prepare()
                                            feedbackGenerator.impactOccurred()
                                            
                                            // Actualizar la última página arrastrada
                                            model.lastDraggedPage = model.targetPage
                                        }
                                    }
                                    .onEnded { value in
                                        // Al soltar, actualizar la página actual con la página objetivo
                                        if let targetPage = model.targetPage {
                                            model.currentPage = targetPage
                                            model.targetPage = nil
                                        }
                                        
                                        // Resetear la última página arrastrada
                                        model.lastDraggedPage = nil
                                        
                                        // Marcar que ya no estamos arrastrando
                                        model.isDraggingProgress = false
                                    }
                            )
                        
                        // Calcular la anchura de la barra de progreso y la posición del círculo
                        let currentPageIndex = CGFloat(model.targetPage != nil ? model.targetPage! : model.currentPage)
                        let maxPageIndex = CGFloat(max(1, model.totalPages - 1))
                        let progressRatio = currentPageIndex / maxPageIndex
                        let progressWidth = geometry.size.width * progressRatio
                        
                        // Barra de progreso
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(model.useWhiteBackground ? Color.black : Color.white)
                            .frame(width: progressWidth, height: 3)
                            .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 1, x: 0, y: 0)
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: model.targetPage)
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: model.currentPage)
                        
                        // Indicador de posición actual (marcador deslizante)
                        ZStack {
                            // Un área táctil más grande semi-transparente para mejor toque
                            Rectangle()
                                .fill(model.useWhiteBackground ? Color.black.opacity(0.001) : Color.white.opacity(0.001))
                                .frame(width: 44, height: 44)
                            
                            // Indicador de posición
                            VStack(spacing: 0) {
                                // Mango superior para arrastrar
                                Capsule()
                                    .fill(model.useWhiteBackground ? Color.black : Color.white)
                                    .frame(width: 6, height: 10)
                                    .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.6) : Color.black.opacity(0.6), radius: 1, x: 0, y: 0)
                                
                                // Línea vertical
                                Rectangle()
                                    .fill(model.useWhiteBackground ? Color.black : Color.white)
                                    .frame(width: 2, height: 6)
                                    .shadow(color: model.useWhiteBackground ? Color.white.opacity(0.6) : Color.black.opacity(0.6), radius: 1, x: 0, y: 0)
                            }
                            .offset(y: -8)
                        }
                        .position(x: max(7, min(geometry.size.width - 7, progressWidth)), y: 2)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: model.targetPage)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: model.currentPage)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Marcar que estamos arrastrando
                                    model.isDraggingProgress = true
                                    
                                    // Calcular la posición relativa del toque en la barra
                                    let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                    
                                    // Calcular la página correspondiente
                                    let newPage = Int(round(percentage * CGFloat(model.totalPages - 1)))
                                    
                                    // Almacenar la página objetivo durante el arrastre
                                    model.targetPage = max(0, min(newPage, model.totalPages - 1))
                                    
                                    // Generar feedback háptico cuando cambia de página durante el arrastre
                                    if model.lastDraggedPage != model.targetPage {
                                        let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
                                        feedbackGenerator.prepare()
                                        feedbackGenerator.impactOccurred()
                                        
                                        // Actualizar la última página arrastrada
                                        model.lastDraggedPage = model.targetPage
                                    }
                                }
                                .onEnded { value in
                                    // Al soltar, actualizar la página actual con la página objetivo
                                    if let targetPage = model.targetPage {
                                        model.currentPage = targetPage
                                        model.targetPage = nil
                                    }
                                    
                                    // Resetear la última página arrastrada
                                    model.lastDraggedPage = nil
                                    
                                    // Marcar que ya no estamos arrastrando
                                    model.isDraggingProgress = false
                                }
                        )
                    }
                    .frame(height: 16) // Aumentar la altura para facilitar el toque
                }
                .frame(height: 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 5)
                
                // Vista previa de miniaturas
                if model.showThumbnails && !model.pages.isEmpty {
                    ThumbnailsPreview(
                        pages: model.pages,
                        currentPage: model.targetPage ?? model.currentPage,
                        totalPages: model.totalPages,
                        useWhiteBackground: model.useWhiteBackground,
                        onPageSelected: { page in
                            model.currentPage = page
                        }
                    )
                    .padding(.bottom, 10)
                }
                
                // Contador de páginas centrado
                HStack {
                    Spacer()
                    Text(model.targetPage != nil ? 
                         "\(model.targetPage! + 1) de \(model.totalPages)" : 
                         "\(model.currentPage + 1) de \(model.totalPages)")
                        .font(.caption)
                        .foregroundColor(model.useWhiteBackground ? .black : .white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: model.targetPage)
                    Spacer()
                }
                .padding(.bottom, 5)
                
                // Controles de navegación
                HStack(spacing: 140) {
                    Button(action: {
                        model.previousPage()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(model.useWhiteBackground ? .black : .white)
                            .padding(12)
                            .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(model.currentPage <= 0)
                    .opacity(model.currentPage <= 0 ? 0.5 : 1.0)
                    
                    Button(action: {
                        model.nextPage()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(model.useWhiteBackground ? .black : .white)
                            .padding(12)
                            .background(model.useWhiteBackground ? Color.gray.opacity(0.2) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(model.currentPage >= model.totalPages - 1)
                    .opacity(model.currentPage >= model.totalPages - 1 ? 0.5 : 1.0)
                }
                .padding(.bottom, 20)
                
                // Información de serie/issue - mantenemos solo esta parte
                if let series = model.book.book.series {
                    HStack {
                        Spacer()
                        
                        Text(series)
                            .font(.footnote)
                            .foregroundColor(model.useWhiteBackground ? .black : .white)
                            .shadow(color: model.useWhiteBackground ? .clear : .black, radius: 2, x: 0, y: 1)
                        
                        if let issue = model.book.book.issueNumber {
                            Text("#\(issue)")
                                .font(.footnote)
                                .foregroundColor(model.useWhiteBackground ? .black : .white)
                                .shadow(color: model.useWhiteBackground ? .clear : .black, radius: 2, x: 0, y: 1)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 5)
                }
            }
        }
    }
}

// MARK: - Vista para el modo webtoon (todas las páginas unidas)
struct WebtoonViewerView: View {
    @ObservedObject var model: ComicViewerModel
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var initialScrollApplied: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        // Marcadores para posicionamiento
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id("scrollTop")
                        
                        ForEach(Array(model.webtoonPages.enumerated()), id: \.element.id) { index, page in
                            Image(uiImage: page.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)
                                .id("page_\(index)") // ID único para cada página
                        }
                        
                        // Marcador final
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id("scrollBottom")
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scrollView")).minY)
                                .onAppear {
                                    scrollViewHeight = proxy.size.height
                                }
                        }
                    )
                }
                .background(model.useWhiteBackground ? Color.white : Color.black)
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    
                    // Calcular y guardar el progreso como un valor entre 0 y 1
                    if scrollViewHeight > geometry.size.height {
                        let maxScroll = scrollViewHeight - geometry.size.height
                        let currentScrollPCT = min(1.0, max(0.0, -scrollOffset / maxScroll))
                        model.lastPageOffsetPCT = Double(currentScrollPCT)
                        
                        // Calcular la página actual aproximada basada en el desplazamiento
                        if model.webtoonPages.count > 0 {
                            let estimatedPage = Int(currentScrollPCT * Double(model.webtoonPages.count - 1))
                            if estimatedPage != model.currentPage {
                                model.currentPage = estimatedPage
                                print("Webtoon: En página estimada \(estimatedPage+1) de \(model.webtoonPages.count), progreso: \(currentScrollPCT * 100)%")
                            }
                        }
                    }
                }
                .onAppear {
                    // Aplicar la posición de desplazamiento inicial si hay un valor guardado
                    if !initialScrollApplied, model.pendingInitialScroll, let savedOffset = model.lastPageOffsetPCT, model.webtoonPages.count > 0 {
                        // Esperar a que la vista se cargue completamente
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Marcar que ya hemos aplicado el desplazamiento inicial
                            initialScrollApplied = true
                            model.pendingInitialScroll = false
                            
                            if model.currentPage > 0 && model.currentPage < model.webtoonPages.count {
                                // Desplazarse a la página aproximada guardada
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("page_\(model.currentPage)", anchor: .top)
                                    
                                    print("Webtoon: Restaurando a la página \(model.currentPage+1)")
                                }
                            } else if savedOffset > 0.01 {
                                // Si no podemos ir a una página específica pero tenemos un offset aproximado,
                                // intentar ir a una posición relativa
                                if savedOffset > 0.9 {
                                    withAnimation {
                                        scrollProxy.scrollTo("scrollBottom", anchor: .bottom)
                                    }
                                } else if savedOffset > 0.05 {
                                    // Para posiciones intermedias, calcular una página aproximada
                                    let estimatedPage = Int(savedOffset * Double(model.webtoonPages.count - 1))
                                    withAnimation {
                                        scrollProxy.scrollTo("page_\(estimatedPage)", anchor: .top)
                                    }
                                }
                                print("Webtoon: Restaurando posición de desplazamiento aproximada \(savedOffset * 100)%")
                            }
                        }
                    }
                }
            }
        }
    }
}

// Clave de preferencia para rastrear el desplazamiento del ScrollView
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Contenedor UIKit para el Visor de Cómics

struct ComicViewerContainer: UIViewControllerRepresentable {
    @ObservedObject var model: ComicViewerModel
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = IVPagingController(model: model)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let controller = uiViewController as? IVPagingController {
            controller.updateReadingMode()
        }
    }
}

// MARK: - Controlador de Paginación

class IVPagingController: UIViewController {
    private var model: ComicViewerModel
    private var collectionView: UICollectionView!
    private var layout: UICollectionViewFlowLayout!
    private var cancellables = Set<AnyCancellable>()
    private var tapGestureRecognizer: UITapGestureRecognizer!
    
    // Definir las regiones de navegación
    private struct NavigationRegion {
        struct Rect {
            let left: CGFloat
            let top: CGFloat
            let right: CGFloat
            let bottom: CGFloat
            
            init(l: CGFloat, t: CGFloat, r: CGFloat, b: CGFloat) {
                left = l
                top = t
                right = r
                bottom = b
            }
            
            func rect(for size: CGSize) -> CGRect {
                return CGRect(
                    x: left * size.width,
                    y: top * size.height,
                    width: (right - left) * size.width,
                    height: (bottom - top) * size.height
                )
            }
        }
        
        enum NavigationType {
            case LEFT
            case RIGHT
            case MENU
        }
        
        let rect: Rect
        let type: NavigationType
    }
    
    // Definir los layouts de regiones de navegación para modo normal (LTR)
    private let comicNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0, t: 0, r: 0.30, b: 1), type: .LEFT),
        .init(rect: .init(l: 0.69, t: 0, r: 1, b: 1), type: .RIGHT),
    ]
    
    // Regiones de navegación para modo manga (RTL) - invertidas respecto a comic
    private let mangaNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0, t: 0, r: 0.30, b: 1), type: .RIGHT),  // Lado izquierdo => acción derecha
        .init(rect: .init(l: 0.69, t: 0, r: 1, b: 1), type: .LEFT),   // Lado derecho => acción izquierda
    ]
    
    private let lNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0.0, t: 0.33, r: 0.33, b: 0.66), type: .LEFT),
        .init(rect: .init(l: 0.0, t: 0.0, r: 1.0, b: 0.33), type: .LEFT),
        .init(rect: .init(l: 0.66, t: 0.33, r: 1.0, b: 0.66), type: .RIGHT),
        .init(rect: .init(l: 0.0, t: 0.66, r: 1.0, b: 1.0), type: .RIGHT),
    ]
    
    // Configuración actual de navegación según modo de lectura
    private var currentNavigationRegions: [NavigationRegion] {
        return model.readingMode == .PAGED_MANGA ? mangaNavigationRegions : comicNavigationRegions
    }
    
    init(model: ComicViewerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupBindings()
        setupGestures()
        
        // Observar notificaciones para cambios en isolateFirstPage
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceUpdateDoublePages(_:)),
            name: Notification.Name("ForceUpdateDoublePages"),
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Actualizar el layout cuando cambia el tamaño de la vista
        let newLayout = createLayout()
        collectionView.setCollectionViewLayout(newLayout, animated: false)
        
        // Asegurar que el collectionView ocupe todo el espacio disponible
        collectionView.frame = view.bounds
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return !model.showControls
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Aplicar el desplazamiento inicial si es necesario
        if model.pendingInitialScroll {
            applyInitialScroll()
        }
    }
    
    private func setupCollectionView() {
        // Crear el layout según el modo de lectura
        layout = createLayout()
        
        // Configurar el collection view para usar todo el espacio disponible
        collectionView = UICollectionView(frame: UIScreen.main.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = model.useWhiteBackground ? .white : .black
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset = .zero
        
        // Optimizaciones de rendimiento
        collectionView.isPrefetchingEnabled = true
        collectionView.prefetchDataSource = self
        
        // Mejorar desplazamiento por página
        collectionView.decelerationRate = .fast
        
        // Asegurarse de que no haya ajustes de SafeArea que afecten el tamaño
        if #available(iOS 11.0, *) {
            collectionView.insetsLayoutMarginsFromSafeArea = false
        }
        
        // Registrar la celda
        collectionView.register(ComicPageCell.self, forCellWithReuseIdentifier: "PageCell")
        
        // Añadir a la vista asegurando que cubra toda la pantalla
        view.addSubview(collectionView)
        
        // Configurar constraints para cubrir todo
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Aplicar transformación según el modo de lectura
        setReadingOrder()
    }
    
    private func setupBindings() {
        // Observar cambios en el modelo
        model.$currentPage
            .sink { [weak self] page in
                guard let self = self, !self.model.isDraggingProgress else { return }
                self.scrollToPage(page)
            }
            .store(in: &cancellables)
        
        model.$readingMode
            .sink { [weak self] newMode in
                guard let self = self else { return }
                
                // Si estamos cambiando a modo vertical, no usar doble página
                if newMode.isVertical {
                    // Nada que hacer aquí, ya se maneja en la vista de configuración
                } else if self.model.doublePaged {
                    // Si no es vertical y tenemos doble página activada, reconstruir las páginas dobles
                    // Ejecutar en el siguiente ciclo de ejecución para evitar actualizaciones cíclicas
                    DispatchQueue.main.async {
                        self.model.buildDoublePages()
                    }
                }
                
                self.updateReadingMode()
            }
            .store(in: &cancellables)
        
        model.$doublePaged
            .sink { [weak self] isDoublePaged in
                guard let self = self else { return }
                
                // Si activamos doble página y no estamos en modo vertical, reconstruir las páginas dobles
                if isDoublePaged && !self.model.readingMode.isVertical {
                    // Construir las páginas dobles inmediatamente
                    self.model.buildDoublePages()
                }
                
                // Actualizar la vista inmediatamente
                self.updateReadingMode()
            }
            .store(in: &cancellables)
            
        // Observar cambios en la opción de aislar la primera página
        model.$isolateFirstPage
            .sink { [weak self] newValue in
                guard let self = self else { return }
                
                // En lugar de hacer la actualización aquí, simplemente registrar el cambio
                // La actualización real se hará a través de la notificación ForceUpdateDoublePages
                print("Valor de isolateFirstPage cambiado a: \(newValue)")
            }
            .store(in: &cancellables)

        // Nuevo monitor para cuando se suelta la barra de progreso
        model.$isDraggingProgress
            .sink { [weak self] isDragging in
                guard let self = self, !isDragging else { return }
                // Cuando se deja de arrastrar, nos desplazamos a la página actual
                DispatchQueue.main.async {
                    self.scrollToPage(self.model.currentPage)
                }
            }
            .store(in: &cancellables)
            
        // Escuchar cambios en la configuración de fondo blanco
        model.$useWhiteBackground
            .sink { [weak self] useWhite in
                guard let self = self else { return }
                // Actualizar el fondo del collection view
                self.collectionView.backgroundColor = useWhite ? .white : .black
                
                // Actualizar todas las celdas visibles
                for cell in self.collectionView.visibleCells {
                    if let pageCell = cell as? ComicPageCell {
                        pageCell.useWhiteBackground = useWhite
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupGestures() {
        // Configurar el gesto de toque para la navegación
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        
        view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    // Método para actualizar los gestos cuando se cargan nuevas celdas
    private func updateGestureRecognizers() {
        // Asegurarse de que el gesto de toque no interfiera con los gestos de doble toque de las celdas
        for cell in collectionView.visibleCells {
            if let pageCell = cell as? ComicPageCell {
                tapGestureRecognizer.require(toFail: pageCell.scrollView.doubleTapGesture)
            }
        }
    }
    
    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: view)
        
        // Verificar si los controles están visibles
        if model.showControls {
            // Si los controles están visibles, solo ocultar los controles
            model.showControls = false
            return
        }
        
        // Determinar la acción según la región tocada
        for region in currentNavigationRegions {
            if region.rect.rect(for: view.bounds.size).contains(location) {
                switch region.type {
                case .LEFT:
                    model.previousPage()
                    return
                case .RIGHT:
                    model.nextPage()
                    return
                default:
                    break
                }
            }
        }
        
        // Si no está en ninguna región definida, mostrar/ocultar el menú
        model.showControls.toggle()
    }
    
    func updateReadingMode() {
        // Si estamos en modo doble página y no en vertical, asegurarnos que las páginas dobles estén construidas
        if model.doublePaged && !model.readingMode.isVertical && model.doublePages.isEmpty {
            model.buildDoublePages()
        }
        
        // Actualizar el layout sin animación para evitar retrasos
        let newLayout = createLayout()
        collectionView.setCollectionViewLayout(newLayout, animated: false)
        
        // Actualizar la transformación
        setReadingOrder()
        
        // Actualizar el comportamiento de desplazamiento de todas las celdas visibles
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? ComicPageCell }
        for cell in visibleCells {
            cell.scrollView.allowVerticalScroll = model.readingMode == .VERTICAL
            cell.scrollView.updateScrollBehavior()
        }
        
        // Volver a cargar los datos
        collectionView.reloadData()
        
        // Actualizar los gestos
        updateGestureRecognizers()
        
        // Desplazarse a la página actual inmediatamente sin animación para mayor fluidez
        scrollToPage(model.currentPage, animated: false)
    }
    
    private func createLayout() -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        
        // Obtener el tamaño real disponible, incluidas las áreas seguras
        let fullScreenSize = UIScreen.main.bounds.size
        
        if model.readingMode.isVertical {
            // Layout vertical para webtoons
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            layout.itemSize = CGSize(width: fullScreenSize.width, height: fullScreenSize.height)
        } else {
            // Layout horizontal para cómics/manga
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            
            if model.doublePaged {
                // Modo de página doble - usar ancho completo para mostrar dos páginas
                layout.itemSize = CGSize(width: fullScreenSize.width, height: fullScreenSize.height)
            } else {
                // Modo de página única - usar el ancho completo disponible
                layout.itemSize = CGSize(width: fullScreenSize.width, height: fullScreenSize.height)
            }
        }
        
        // Asegurar que no haya márgenes
        layout.sectionInset = UIEdgeInsets.zero
        
        return layout
    }
    
    private func setReadingOrder() {
        guard !model.readingMode.isVertical else {
            // No aplicar transformación para modo vertical
            collectionView.transform = .identity
            return
        }
        
        if model.readingMode.isInverted && model.doublePaged {
            // En modo manga con páginas dobles, aplicar transformación para invertir la dirección del scroll
            // Esto cambiará el comportamiento del desplazamiento sin afectar la visualización
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
        } else {
            // En otros modos, no aplicar transformación
            collectionView.transform = .identity
        }
    }
    
    private func scrollToPage(_ page: Int, animated: Bool = false) {
        guard page >= 0 && page < model.pages.count else { return }
        
        // Asegurarse primero de que la colección esté actualizada
        if model.doublePaged && model.doublePages.isEmpty && !model.readingMode.isVertical {
            model.buildDoublePages()
        }
        
        if model.readingMode.isVertical {
            // En modo vertical, el índice en el CollectionView coincide con el índice real
            let indexPath = IndexPath(item: page, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
            
            // Restaurar posición vertical dentro de la página si hay un offset guardado
            if let offset = model.lastPageOffsetPCT {
                // Aplicar inmediatamente sin espera para mejorar la fluidez
                if let cell = collectionView.cellForItem(at: indexPath) as? ComicPageCell {
                    let scrollView = cell.scrollView
                    let contentHeight = scrollView.contentSize.height
                    let frameHeight = scrollView.frame.height
                    
                    // Solo aplicar si el contenido es más alto que la vista
                    if contentHeight > frameHeight {
                        let maxOffset = contentHeight - frameHeight
                        let targetOffset = CGFloat(offset) * maxOffset
                        
                        // Establecer la posición de desplazamiento
                        scrollView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
                    }
                }
            }
        } else if model.doublePaged && !model.doublePages.isEmpty {
            // En modo doble página, encontrar en qué página doble se encuentra la página actual
            var doublePageIndex = 0
            var found = false
            
            for (i, doublePage) in model.doublePages.enumerated() {
                let globalIndex = model.pageToGlobalIndex(doublePageIndex: i, pageInDoublePage: 0)
                let secondPageIndex = doublePage.rightImage != nil ? globalIndex + 1 : globalIndex
                
                if globalIndex <= page && page <= secondPageIndex {
                    doublePageIndex = i
                    found = true
                    break
                }
            }
            
            if found {
                // Usar un retraso mínimo para asegurar que la colección esté lista
                DispatchQueue.main.async {
                    let indexPath = IndexPath(item: doublePageIndex, section: 0)
                    // Desplazamiento directo para mayor fluidez
                    self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
                    
                    // Forzar un redibujado inmediato
                    self.collectionView.layoutIfNeeded()
                }
            }
        } else {
            // Modo de página única
            // Convertir el índice de página real al índice visual en el CollectionView según el modo de lectura
            let visualIndex: Int
            if model.readingMode.isInverted && !model.readingMode.isVertical {
                // En modo manga, el índice visual es inverso al índice real
                visualIndex = model.pages.count - 1 - page
            } else {
                visualIndex = page
            }
            
            let indexPath = IndexPath(item: visualIndex, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
        }
    }
    
    private func applyInitialScroll() {
        // Asegurarse de que solo se aplique una vez
        model.pendingInitialScroll = false
        
        // Desplazarse a la página guardada
        scrollToPage(model.currentPage, animated: false)
        
        // Imprimir información de depuración
        print("Aplicando desplazamiento inicial a la página \(model.currentPage + 1) de \(model.totalPages)")
        if let offset = model.lastPageOffsetPCT {
            print("Con posición vertical: \(offset * 100)%")
        }
    }
    
    @objc private func handleForceUpdateDoublePages(_ notification: Notification) {
        // Forzar la reconstrucción de páginas dobles y la actualización de la vista
        guard model.doublePaged && !model.readingMode.isVertical else { return }
        
        // Guardar la página actual
        let currentPage = model.currentPage
        
        print("Forzando actualización de páginas dobles")
        
        // Limpiar páginas dobles existentes para forzar reconstrucción
        model.doublePages = []
        
        // Forzar una pausa breve para asegurar que los cambios de estado se apliquen
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reconstruir páginas dobles
            self.model.buildDoublePages()
            
            // Recargar los datos inmediatamente
            self.collectionView.reloadData()
            
            // Asegurar que la vista se desplace a la página correcta
            self.scrollToPage(currentPage, animated: false)
            
            // Forzar layout inmediato
            self.collectionView.layoutIfNeeded()
            
            // Agregar una segunda actualización con un pequeño retraso
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.collectionView.reloadData()
                self.scrollToPage(currentPage, animated: false)
                self.collectionView.layoutIfNeeded()
            }
        }
    }
}

// MARK: - Extensiones del Controlador de Paginación

extension IVPagingController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if model.readingMode.isVertical {
            return model.pages.count
        } else if model.doublePaged {
            return model.doublePages.count
        } else {
            return model.pages.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCell", for: indexPath) as? ComicPageCell else {
            return UICollectionViewCell()
        }
        
        // Aplicar la transformación inversa a la celda si estamos en modo manga con páginas dobles
        if model.readingMode.isInverted && model.doublePaged {
            cell.contentView.transform = CGAffineTransform(scaleX: -1, y: 1)
        } else {
            cell.contentView.transform = .identity
        }
        
        if model.readingMode.isVertical {
            // Modo vertical (webtoon) - configuración normal
            let pageIndex = indexPath.item
            if pageIndex < model.pages.count {
                let image = model.pages[pageIndex]
                cell.configureSinglePage(image: image, readingMode: model.readingMode, useWhiteBackground: model.useWhiteBackground)
                tapGestureRecognizer.require(toFail: cell.scrollView.doubleTapGesture)
            }
        } else if model.doublePaged {
            // Modo de página doble
            let doublePageIndex = indexPath.item
            if doublePageIndex < model.doublePages.count {
                let doublePage = model.doublePages[doublePageIndex]
                
                if let rightImage = doublePage.rightImage {
                    // Si hay dos imágenes, configurar para mostrar ambas
                    cell.configureDoublePage(
                        leftImage: doublePage.leftImage,
                        rightImage: rightImage,
                        readingMode: model.readingMode,
                        useWhiteBackground: model.useWhiteBackground
                    )
                } else {
                    // Si solo hay una imagen (página ancha o página única), mostrar una sola
                    cell.configureSinglePage(
                        image: doublePage.leftImage,
                        readingMode: model.readingMode,
                        useWhiteBackground: model.useWhiteBackground
                    )
                }
                
                tapGestureRecognizer.require(toFail: cell.scrollView.doubleTapGesture)
            }
        } else {
            // Modo de página única
    
            let pageIndex: Int
            if model.readingMode.isInverted && !model.readingMode.isVertical {
                // En modo manga invertimos el orden de las páginas
                pageIndex = model.pages.count - 1 - indexPath.item
            } else {
                pageIndex = indexPath.item
            }
            
            if pageIndex < model.pages.count {
                let image = model.pages[pageIndex]
                cell.configureSinglePage(image: image, readingMode: model.readingMode, useWhiteBackground: model.useWhiteBackground)
                
                // Actualizar los gestos para esta celda
                tapGestureRecognizer.require(toFail: cell.scrollView.doubleTapGesture)
            }
        }
        
        return cell
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Actualizar la página actual cuando el desplazamiento se detiene
        let pageWidth = scrollView.frame.width
        let pageHeight = scrollView.frame.height
        
        if model.readingMode.isVertical {
            // Cálculo para desplazamiento vertical (sin cambios)
            let page = Int(floor(scrollView.contentOffset.y / pageHeight))
            if page != model.currentPage {
                model.currentPage = max(0, min(page, model.pages.count - 1))
                
                // Calcular la posición dentro de la página para webtoons
                if let cell = collectionView.cellForItem(at: IndexPath(item: model.currentPage, section: 0)) as? ComicPageCell {
                    updatePageOffset(for: cell)
                }
            } else {
                // Incluso si la página no cambió, actualizar la posición dentro de la página
                if let cell = collectionView.cellForItem(at: IndexPath(item: model.currentPage, section: 0)) as? ComicPageCell {
                    updatePageOffset(for: cell)
                }
            }
        } else if model.doublePaged {
            // Cálculo para desplazamiento en modo doble página
            let visualIndex = Int(floor(scrollView.contentOffset.x / pageWidth))
            
            if visualIndex < model.doublePages.count {
                // Obtener el índice global de página desde la página doble visible
                let doublePageIndex = visualIndex
                let globalIndex = model.pageToGlobalIndex(doublePageIndex: doublePageIndex, pageInDoublePage: 0)
                
                if globalIndex != model.currentPage {
                    model.currentPage = globalIndex
                }
            }
        } else {
            // Cálculo para desplazamiento horizontal en modo página única
            let visualIndex = Int(floor(scrollView.contentOffset.x / pageWidth))
            
            // Convertir el índice visual al índice real de página según el modo de lectura
            let pageIndex: Int
            if model.readingMode.isInverted && !model.readingMode.isVertical {
                // En modo manga, el índice real es inverso al índice visual
                pageIndex = model.pages.count - 1 - visualIndex
            } else {
                pageIndex = visualIndex
            }
            
            if pageIndex != model.currentPage {
                model.currentPage = max(0, min(pageIndex, model.pages.count - 1))
            }
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // Actualizar la escala en el modelo
        model.scale = scale
        
        // Actualizar la posición dentro de la página si estamos en modo vertical
        if model.readingMode.isVertical {
            if let indexPath = collectionView.indexPathsForVisibleItems.first,
               let cell = collectionView.cellForItem(at: indexPath) as? ComicPageCell {
                updatePageOffset(for: cell)
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate && model.readingMode.isVertical {
            // Si no va a desacelerar, actualizar la posición inmediatamente
            if let indexPath = collectionView.indexPathsForVisibleItems.first,
               let cell = collectionView.cellForItem(at: indexPath) as? ComicPageCell {
                updatePageOffset(for: cell)
            }
        }
    }
    
    private func updatePageOffset(for cell: ComicPageCell) {
        // Calcular la posición relativa dentro de la página
        let scrollView = cell.scrollView
        let frame = scrollView.frame
        let contentSize = scrollView.contentSize
        
        // Solo calcular para webtoons (contenido más alto que la pantalla)
        if contentSize.height > frame.height {
            let offset = scrollView.contentOffset.y
            let maxOffset = contentSize.height - frame.height
            
            // Calcular el porcentaje de desplazamiento (0-1)
            if maxOffset > 0 {
                let percentage = Double(offset / maxOffset)
                model.lastPageOffsetPCT = max(0.0, min(1.0, percentage))
                if let offsetPCT = model.lastPageOffsetPCT {
                    print("Actualizando posición vertical: \(offsetPCT * 100)%")
                }
            }
        }
    }
}

// MARK: - Celda para Página de Cómic

class ComicPageCell: UICollectionViewCell {
    var scrollView: ZoomingScrollView
    var useWhiteBackground: Bool = false {
        didSet {
            scrollView.backgroundColor = useWhiteBackground ? .white : .black
        }
    }
    
    // Vistas adicionales para el modo de doble página
    private var leftImageView: UIImageView?
    private var rightImageView: UIImageView?
    private var leftRightContainer: UIView?
    private var singleImageView: UIImageView?
    
    override init(frame: CGRect) {
        // Usar el frame proporcionado en lugar de un tamaño fijo de pantalla
        scrollView = ZoomingScrollView(frame: frame)
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Añadir el scroll view a la vista
        contentView.addSubview(scrollView)
        
        // Configurar constraints para ocupar todo el espacio
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // Asegurarse que la celda no tenga espacios adicionales
        contentView.clipsToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Asegurar que el scrollView tenga el tamaño correcto
        scrollView.frame = contentView.bounds
    }
    
    func configure(with image: UIImage, readingMode: ReadingMode, useWhiteBackground: Bool = false) {
        // Ya no aplicamos transformación para manga
        scrollView.transform = .identity
        
        // Limpiar cualquier configuración anterior de doble página
        cleanupDoublePageViews()
        
        // Configurar la imagen
        scrollView.display(image: image)
        
        // Configurar el bloqueo de scroll vertical según el modo de lectura
        scrollView.allowVerticalScroll = readingMode == .VERTICAL
        scrollView.updateScrollBehavior()
        
        // Configurar el fondo
        self.useWhiteBackground = useWhiteBackground
    }
    
    func configureDoublePage(leftImage: UIImage, rightImage: UIImage, readingMode: ReadingMode, useWhiteBackground: Bool = false) {
        // Limpiar cualquier configuración anterior
        cleanupDoublePageViews()
        scrollView.reset()
        
        // Crear un nuevo contenedor
        let container = UIView()
        leftRightContainer = container
        
        // Crear las vistas de imagen
        let leftView = UIImageView()
        let rightView = UIImageView()
        leftImageView = leftView
        rightImageView = rightView
        
        // Configurar las vistas de imagen
        leftView.contentMode = .scaleAspectFit
        rightView.contentMode = .scaleAspectFit
        
        // Si la celda tiene una transformación espejada, invertir el orden
        // La transformación se aplica cuando estamos en modo manga con páginas dobles
        if contentView.transform == CGAffineTransform(scaleX: -1, y: 1) {
            // En modo manga con transformación, invertir el orden de las imágenes
            // para compensar el efecto espejo
            leftView.image = rightImage
            rightView.image = leftImage
        } else {
            // En modo normal, mantener el orden original
            leftView.image = leftImage
            rightView.image = rightImage
        }
        
        // Agregar las vistas al contenedor
        container.addSubview(leftView)
        container.addSubview(rightView)
        
        // Configurar constraints del contenedor
        container.translatesAutoresizingMaskIntoConstraints = false
        leftView.translatesAutoresizingMaskIntoConstraints = false
        rightView.translatesAutoresizingMaskIntoConstraints = false
        
        // Agregar constraints para las imágenes dentro del contenedor
        NSLayoutConstraint.activate([
            // Imagen izquierda
            leftView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftView.topAnchor.constraint(equalTo: container.topAnchor),
            leftView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leftView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5),
            
            // Imagen derecha
            rightView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rightView.topAnchor.constraint(equalTo: container.topAnchor),
            rightView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rightView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5)
        ])
        
        // Configurar scroll view para el contenedor completo
        scrollView.allowVerticalScroll = false
        scrollView.updateScrollBehavior()
        scrollView.setupZoomForView(container)
        
        // Configurar el fondo
        self.useWhiteBackground = useWhiteBackground
    }
    
    private func cleanupDoublePageViews() {
        // Primero, desactivar todas las constraints para evitar errores
        if let container = leftRightContainer {
            NSLayoutConstraint.deactivate(container.constraints)
            leftImageView?.removeFromSuperview()
            rightImageView?.removeFromSuperview()
            container.removeFromSuperview()
        }
        
        // Luego establecer las referencias a nil
        leftImageView = nil
        rightImageView = nil
        leftRightContainer = nil
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Limpiar todos los recursos
        singleImageView = nil
        
        // Limpiar todas las vistas adicionales
        scrollView.reset()
        cleanupDoublePageViews()
        
        // Establecer contenido nulo
        for subview in contentView.subviews {
            if subview != scrollView {
                subview.removeFromSuperview()
            }
        }
    }
    
    func configureSinglePage(image: UIImage, readingMode: ReadingMode, useWhiteBackground: Bool = false) {
        // Limpiar cualquier configuración anterior para evitar problemas con constraints
        cleanupDoublePageViews()
        scrollView.reset()
        
        // Crear la vista de imagen
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        singleImageView = imageView
        
        // Configurar el scroll view para la nueva vista
        scrollView.allowVerticalScroll = (readingMode == .VERTICAL)
        scrollView.updateScrollBehavior()
        scrollView.setupZoomForView(imageView)
        
        // Configurar el fondo
        self.useWhiteBackground = useWhiteBackground
    }
}

// MARK: - ScrollView con Zoom

class ZoomingScrollView: UIScrollView {
    private var imageView: UIImageView!
    var doubleTapGesture: UITapGestureRecognizer!
    private var wrapper: UIView!
    private var postImageSetConstraints: [NSLayoutConstraint] = []
    var allowVerticalScroll: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
        setupWrapper()
        setupImageView()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupScrollView() {
        backgroundColor = .clear
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        decelerationRate = .fast
        delegate = self
        contentInsetAdjustmentBehavior = .never
        
        // Desactivar el rebote para un mejor control del contenido
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        bounces = false
        
        // Configurar zoom
        minimumZoomScale = 1.0
        maximumZoomScale = 3.0
        bouncesZoom = true
        
        // Asegurarse de que el scrollView ignore los márgenes de seguridad
        if #available(iOS 11.0, *) {
            contentInsetAdjustmentBehavior = .never
            insetsLayoutMarginsFromSafeArea = false
            verticalScrollIndicatorInsets = .zero
            horizontalScrollIndicatorInsets = .zero
        }
    }
    
    // Método para actualizar la configuración de desplazamiento según el modo de lectura
    func updateScrollBehavior() {
        // Configurar el comportamiento de rebote según si permitimos desplazamiento vertical
        alwaysBounceVertical = allowVerticalScroll
        // Si estamos en modo vertical (webtoon), permitir rebote, en caso contrario no
        bounces = allowVerticalScroll
    }
    
    private func setupWrapper() {
        // Verificar si ya existe un wrapper y está configurado correctamente
        if let existingWrapper = wrapper, existingWrapper.superview == self {
            return
        }
        
        // Crear un contenedor que coincide con el tamaño de la pantalla
        let screenBounds = UIScreen.main.bounds
        wrapper = UIView(frame: screenBounds)
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.clipsToBounds = true
        
        // Agregar a la vista
        if let existingWrapper = wrapper, existingWrapper.superview != self {
            addSubview(existingWrapper)
        }
        
        // El wrapper debe ocupar todo el espacio disponible
        NSLayoutConstraint.activate([
            wrapper.centerYAnchor.constraint(equalTo: centerYAnchor),
            wrapper.centerXAnchor.constraint(equalTo: centerXAnchor),
            wrapper.widthAnchor.constraint(equalTo: widthAnchor),
            wrapper.heightAnchor.constraint(equalTo: heightAnchor)
        ])
    }
    
    private func setupImageView() {
        // Verificar que wrapper existe
        guard wrapper != nil else { return }
        
        if imageView != nil {
            // Si ya existe, solo asegurarse de que está en su lugar correcto
            if imageView.superview != wrapper {
                imageView.removeFromSuperview()
                wrapper.addSubview(imageView)
            }
            return
        }
        
        // Crear nuevo imageView
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.layer.allowsEdgeAntialiasing = true
        imageView.layer.magnificationFilter = .linear
        imageView.layer.minificationFilter = .trilinear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(imageView)
    }
    
    private func setupGestures() {
        // Gesto de doble toque para zoom
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
    }
    
    func display(image: UIImage) {
        // Verificar que el imageView exista
        guard imageView != nil else {
            // Si no existe, recrear el imageView
            setupImageView()
            display(image: image)
            return
        }
        
        // Configurar la imagen
        imageView.image = image
        
        // Resetear el zoom
        zoomScale = 1.0
        
        // Limpiar restricciones anteriores
        NSLayoutConstraint.deactivate(postImageSetConstraints)
        postImageSetConstraints.removeAll()
        
        // Actualizar el frame de la imagen
        didUpdateSize(size: image.size)
        
        // Actualizar el comportamiento de desplazamiento
        updateScrollBehavior()
    }
    
    func reset() {
        // Desactivar observador de delegado temporalmente para evitar llamadas durante la limpieza
        delegate = nil
        
        // Limpiar la imagen y resetear el zoom
        if imageView != nil {
            imageView.image = nil
        }
        zoomScale = 1.0
        contentOffset = .zero
        
        // Limpiar restricciones anteriores
        NSLayoutConstraint.deactivate(postImageSetConstraints)
        postImageSetConstraints.removeAll()
        
        // Restaurar el delegado
        delegate = self
    }
    
    func didUpdateSize(size: CGSize) {
        // Verificar que imageView existe
        guard imageView != nil else { return }
        
        // Verificar que wrapper existe
        guard wrapper != nil else { return }
        
        // Limpiar restricciones previas
        NSLayoutConstraint.deactivate(postImageSetConstraints)
        postImageSetConstraints.removeAll()
        
        // Asegurarse de que la imagen ocupe el tamaño completo disponible
        // mientras mantiene su relación de aspecto
        let imageAspect = size.width / size.height
        let viewAspect = bounds.width / bounds.height
        
        // Decidir cómo ajustar la imagen para llenar la pantalla
        if imageAspect > viewAspect {
            // La imagen es más ancha proporcionalmente - ajustar por ancho
            postImageSetConstraints.append(contentsOf: [
                imageView.widthAnchor.constraint(equalTo: wrapper.widthAnchor),
                imageView.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: size.height / size.width)
            ])
        } else {
            // La imagen es más alta proporcionalmente - ajustar por altura
            postImageSetConstraints.append(contentsOf: [
                imageView.heightAnchor.constraint(equalTo: wrapper.heightAnchor),
                imageView.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: size.width / size.height)
            ])
        }
        
        // Activar las restricciones
        NSLayoutConstraint.activate(postImageSetConstraints)
        
        // Actualizar el contenido del scroll view
        contentSize = wrapper.frame.size
        
        // Aplicar centrado inicial
        DispatchQueue.main.async { [weak self] in
            self?.setZoomPosition()
        }
    }
    
    func setZoomPosition() {
        // Para centrar la imagen inicialmente, usamos contenido más amplio y aplicamos insets
        // Esto asegura que las imágenes estén centradas correctamente y el zoom funcione bien
        guard let imageView = imageView, let image = imageView.image else { return }
        
        let imageSize = image.size
        let viewSize = bounds.size
        
        // Calcular el tamaño que la imagen debería tener a escala 1
        let horizontalScale = viewSize.width / imageSize.width
        let verticalScale = viewSize.height / imageSize.height
        
        // Determinar qué escala usar para llenar la pantalla manteniendo la relación de aspecto
        let minScale = min(horizontalScale, verticalScale)
        
        // Calcular las dimensiones de la imagen escalada
        let scaledWidth = imageSize.width * minScale
        let scaledHeight = imageSize.height * minScale
        
        // Calcular los insets para centrar
        var horizontalInset: CGFloat = 0
        var verticalInset: CGFloat = 0
        
        if scaledWidth < viewSize.width {
            horizontalInset = (viewSize.width - scaledWidth) / 2
        }
        
        if scaledHeight < viewSize.height {
            verticalInset = (viewSize.height - scaledHeight) / 2
        }
        
        // Aplicar insets para centrar
        contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        handleZoom(to: location, animated: true)
    }
    
    func handleZoom(to point: CGPoint, animated: Bool) {
        // Si estamos en zoom mínimo, hacer zoom a la ubicación tocada
        // Si estamos en zoom aumentado, volver al zoom mínimo
        if zoomScale <= minimumZoomScale + 0.01 {
            // Calcular el rectángulo para hacer zoom
            let width = bounds.width / maximumZoomScale
            let height = bounds.height / maximumZoomScale
            
            // Centrar en el punto tocado
            let zoomX = point.x - (width / 2)
            let zoomY = point.y - (height / 2)
            
            // Crear el rectángulo para zoom
            let zoomRect = CGRect(x: zoomX, y: zoomY, width: width, height: height)
            
            // Hacer zoom a ese rectángulo
            zoom(to: zoomRect, animated: animated)
        } else {
            // Volver al tamaño normal
            setZoomScale(minimumZoomScale, animated: animated)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Solo actualizar las restricciones si ha cambiado el tamaño
        let currentSize = bounds.size
        guard let imageView = imageView, 
              let image = imageView.image, 
              !postImageSetConstraints.isEmpty else { return }
        
        // Es importante actualizar el zoom center cuando cambia el tamaño
        let zoomCenter = CGPoint(x: contentOffset.x + currentSize.width / 2.0,
                                y: contentOffset.y + currentSize.height / 2.0)
        
        // Restablecemos las restricciones, pero mantenemos el zoom
        let currentZoom = zoomScale
        didUpdateSize(size: image.size)
        
        // Mantener el nivel de zoom después de actualizar el layout
        if currentZoom != 1.0 {
            setZoomScale(currentZoom, animated: false)
            
            // Intentar mantener el mismo centro después del cambio de tamaño
            let newContentOffset = CGPoint(
                x: zoomCenter.x - currentSize.width / 2.0,
                y: zoomCenter.y - currentSize.height / 2.0
            )
            setContentOffset(newContentOffset, animated: false)
        }
    }
    
    func setupZoomForView(_ view: UIView) {
        // Desactivar temporalmente el delegado para evitar disparar eventos durante la configuración
        delegate = nil
        
        // Resetear propiedades principales
        zoomScale = 1.0
        contentOffset = .zero
        
        // Limpiar restricciones anteriores
        NSLayoutConstraint.deactivate(postImageSetConstraints)
        postImageSetConstraints.removeAll()
        
        // Limpiar las vistas anteriores de forma segura
        if let existingWrapper = wrapper, existingWrapper != view {
            // Desactivar todas las constraints existentes de manera segura
            for constraint in existingWrapper.constraints {
                constraint.isActive = false
            }
            
            for constraint in constraints {
                constraint.isActive = false
            }
            
            // Remover imágenes y el wrapper anterior de manera segura
            if let existingImageView = imageView {
                existingImageView.removeFromSuperview()
            }
            imageView = nil
            
            existingWrapper.removeFromSuperview()
        }
        
        // Establecer el nuevo wrapper
        wrapper = view
        
        // Remover vista del superview anterior si existe
        if view.superview != nil && view.superview != self {
            view.removeFromSuperview()
        }
        
        // Agregar el nuevo wrapper como subview si no lo está ya
        if view.superview != self {
            addSubview(view)
        }
        
        // Limpiar y aplicar nuevas constraints
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Crear y activar nuevas constraints de forma segura
        let newConstraints = [
            view.centerXAnchor.constraint(equalTo: centerXAnchor),
            view.centerYAnchor.constraint(equalTo: centerYAnchor),
            view.widthAnchor.constraint(equalTo: widthAnchor),
            view.heightAnchor.constraint(equalTo: heightAnchor)
        ]
        
        // Activar constraints
        NSLayoutConstraint.activate(newConstraints)
        
        // Ajustar configuración de zoom
        minimumZoomScale = 1.0
        maximumZoomScale = 3.0
        
        // Restaurar el delegado
        delegate = self
    }
}

// Extensión para implementar el delegado de UIScrollView
extension ZoomingScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return wrapper
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Centrar el contenido cuando se hace zoom
        let zoomedContentSize = CGSize(
            width: wrapper.frame.width * zoomScale,
            height: wrapper.frame.height * zoomScale
        )
        
        let boundsSize = bounds.size
        
        // Calcular offsets para mantener el contenido centrado
        var frameOffsetX: CGFloat = 0
        var frameOffsetY: CGFloat = 0
        
        // Calcular desplazamientos horizontales y verticales
        if zoomedContentSize.width < boundsSize.width {
            frameOffsetX = (boundsSize.width - zoomedContentSize.width) / 2.0
        }
        
        if zoomedContentSize.height < boundsSize.height {
            frameOffsetY = (boundsSize.height - zoomedContentSize.height) / 2.0
        }
        
        // Aplicar los insets calculados
        contentInset = UIEdgeInsets(
            top: frameOffsetY,
            left: frameOffsetX,
            bottom: frameOffsetY,
            right: frameOffsetX
        )
    }
    
    // Controlar el desplazamiento vertical
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: self)
            
            // Si el zoom está activo, permitir el desplazamiento en cualquier dirección
            if zoomScale > minimumZoomScale {
                return true
            }
            
            // Si el desplazamiento vertical no está permitido y el gesto es principalmente vertical
            if !allowVerticalScroll && abs(velocity.y) > abs(velocity.x) {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

// MARK: - Vista Previa

struct EnhancedComicViewer_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedComicViewer(book: CompleteBook(
            title: "Spider-Man: No Way Home",
            author: "Marvel Comics",
            coverImage: "comic1",
            type: .cbz,
            progress: 0.5
        ))
    }
}

// MARK: - Vista de Configuración del Cómic
struct ComicSettingsView: View {
    @Binding var readingMode: ReadingMode
    @Binding var doublePaged: Bool
    @Binding var isolateFirstPage: Bool
    @Binding var useWhiteBackground: Bool
    @Binding var showThumbnails: Bool
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Fondo con efecto de blur
            Color.black.opacity(0.5)
                .background(Color.black.opacity(0.2))
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            // Panel de configuración con diseño moderno
            VStack(spacing: 0) {
                // Encabezado con diseño mejorado
                HStack {
                    Text("Configuración")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 24)
                
                Divider()
                    .background(Color.secondary.opacity(0.2))
                    .padding(.horizontal, 24)
                
                // Contenido principal con scroll
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Selector de modo de lectura
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MODO DE LECTURA")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 12) {
                                ForEach(ReadingMode.allCases) { mode in
                                    ReadingModeRow(
                                        mode: mode,
                                        isSelected: readingMode == mode,
                                        action: {
                                            withAnimation {
                                                // Cambiar el modo de lectura primero
                                                readingMode = mode
                                                
                                                // Si cambiamos a modo vertical, desactivar páginas dobles
                                                // pero hacerlo en el siguiente ciclo para evitar actualizaciones cíclicas
                                                if mode.isVertical && doublePaged {
                                                    DispatchQueue.main.async {
                                                        doublePaged = false
                                                    }
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Otras opciones
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPCIONES")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 16) {
                                // Opción de páginas dobles
                                if !readingMode.isVertical {
                                    SettingsToggleRow(
                                        title: "Páginas dobles",
                                        subtitle: "Muestra dos páginas simultáneamente",
                                        iconName: "book.pages.fill",
                                        isEnabled: true,
                                        isActive: doublePaged,
                                        binding: $doublePaged
                                    )
                                    
                                    // Opción de aislar primera página (mostrarla sola)
                                    if doublePaged {
                                        // Volver a usar SettingsToggleRow con un binding personalizado
                                        SettingsToggleRow(
                                            title: "Combinar portada",
                                            subtitle: "Mostrar la primera página junto con otra (cuando está activado) o por separado (cuando está desactivado)",
                                            iconName: "doc.viewfinder",
                                            isEnabled: doublePaged,
                                            isActive: isolateFirstPage,
                                            binding: Binding(
                                                get: { isolateFirstPage },
                                                set: { newValue in
                                                    // Cambiar el valor directamente
                                                    isolateFirstPage = newValue
                                                    
                                                    // Forzar actualización inmediata de la UI
                                                    DispatchQueue.main.async {
                                                        // Notificar el cambio para actualizar la vista inmediatamente
                                                        NotificationCenter.default.post(
                                                            name: Notification.Name("ForceUpdateDoublePages"),
                                                            object: nil,
                                                            userInfo: ["isolateFirstPage": newValue]
                                                        )
                                                    }
                                                }
                                            )
                                        )
                                        .padding(.leading, 24)
                                    }
                                }
                                
                                // Opción de fondo blanco
                                SettingsToggleRow(
                                    title: "Fondo claro",
                                    subtitle: "Cambia entre fondos claro y oscuro para una lectura más cómoda",
                                    iconName: useWhiteBackground ? "sun.max.fill" : "moon.fill",
                                    isEnabled: true,
                                    isActive: useWhiteBackground,
                                    binding: $useWhiteBackground
                                )
                                
                                // Opción para mostrar/ocultar miniaturas
                                SettingsToggleRow(
                                    title: "Vista previa de miniaturas",
                                    subtitle: "Muestra miniaturas de las páginas encima de la barra de progreso",
                                    iconName: "photo.on.rectangle",
                                    isEnabled: true,
                                    isActive: showThumbnails,
                                    binding: $showThumbnails
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Información de la app
                        VStack {
                            Text("Chrono Reader")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top)
                            Text("v1.0")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
                
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.85, 380))
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, UIScreen.main.bounds.height < 700 ? 20 : 40)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
        }
        .zIndex(10)
    }
}

// MARK: - Componentes para la vista de configuración

// Vista de fila para modo de lectura
struct ReadingModeRow: View {
    let mode: ReadingMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // Icono
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
            
            // Textos
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Indicador de selección
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(backgroundColor)
        .overlay(borderOverlay)
        .onTapGesture {
            action()
        }
    }
    
    // Propiedades computadas para simplificar la vista
    private var iconName: String {
        switch mode {
        case .PAGED_COMIC:
            return "arrow.right"
        case .PAGED_MANGA:
            return "arrow.left"
        case .VERTICAL:
            return "arrow.down"
        }
    }
    
    private var description: String {
        switch mode {
        case .PAGED_COMIC:
            return "Avanza páginas de izquierda a derecha (estilo occidental)"
        case .PAGED_MANGA:
            return "Avanza páginas de derecha a izquierda (estilo japonés)"
        case .VERTICAL:
            return "Desplazamiento vertical continuo (estilo webtoon)"
        }
    }
    
    private var backgroundColor: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? 
                  Color.accentColor.opacity(0.1) : 
                  Color.secondary.opacity(0.05))
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                lineWidth: 1
            )
    }
}

// Vista de fila para opciones con toggle
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    var iconColor: Color? = nil
    let isEnabled: Bool
    let isActive: Bool
    @Binding var binding: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 14) {
                // Icono
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor != nil ? iconColor : (isActive ? .accentColor : .primary))
                }
                
                // Textos
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // Control Toggle simplificado
            Toggle("", isOn: $binding)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)
                .frame(width: 55)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

// MARK: - Modificadores Personalizados para Ocultar la Barra de Gestos

extension View {
    func persistentSystemOverlaysSupressed(showControls: Bool = false) -> some View {
        if #available(iOS 16.0, *) {
            return self.persistentSystemOverlays(showControls ? .automatic : .hidden)
        } else {
            return self
        }
    }
} 

// MARK: - Implementación de prefetching para mejorar el rendimiento
extension IVPagingController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Este método permite precargar las imágenes que están a punto de mostrarse
        for indexPath in indexPaths {
            if model.readingMode.isVertical {
                // Precarga para modo vertical
                if indexPath.item < model.pages.count {
                    // Las imágenes ya están cargadas en el modelo, no necesitamos hacer nada adicional
                }
            } else if model.doublePaged {
                // Precarga para modo doble página
                if indexPath.item < model.doublePages.count {
                    // Las double pages ya están construidas en el modelo
                }
            } else {
                // Precarga para modo página única
                let pageIndex = model.readingMode.isInverted && !model.readingMode.isVertical 
                    ? model.pages.count - 1 - indexPath.item 
                    : indexPath.item
                    
                if pageIndex < model.pages.count {
                    // Las imágenes ya están cargadas en el modelo
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancelar cualquier carga de imágenes para elementos que ya no son necesarios
        // Como estamos usando imágenes ya cargadas en memoria, no necesitamos hacer nada aquí
    }
}

// MARK: - Vista previa de miniaturas

struct ThumbnailsPreview: View {
    let pages: [UIImage]
    let currentPage: Int
    let totalPages: Int
    let useWhiteBackground: Bool
    let onPageSelected: (Int) -> Void
    
    @State private var scrollViewWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Button(action: {
                                onPageSelected(index)
                            }) {
                                Image(uiImage: pages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 90)
                                    .cornerRadius(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(currentPage == index ? 
                                                    (useWhiteBackground ? Color.black : Color.white) : 
                                                    Color.clear, 
                                                   lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 10))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(5)
                                            .padding(2),
                                        alignment: .bottomTrailing
                                    )
                                    .id(index)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .onAppear {
                        scrollViewWidth = geometry.size.width
                        // Desplazar a la página actual cuando aparece la vista
                        scrollToCurrentPage(scrollProxy: scrollProxy)
                    }
                    .onChange(of: currentPage) { _ in
                        // Desplazar a la página actual cuando cambia
                        scrollToCurrentPage(scrollProxy: scrollProxy)
                    }
                }
            }
        }
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(useWhiteBackground ? Color.white.opacity(0.8) : Color.black.opacity(0.5))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
    }
    
    private func scrollToCurrentPage(scrollProxy: ScrollViewProxy) {
        withAnimation {
            scrollProxy.scrollTo(currentPage, anchor: .center)
        }
    }
}