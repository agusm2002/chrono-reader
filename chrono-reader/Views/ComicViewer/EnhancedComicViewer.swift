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

class ComicViewerModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var pages: [UIImage] = []
    @Published var isLoading: Bool = true
    @Published var readingMode: ReadingMode = .PAGED_COMIC
    @Published var showControls: Bool = true
    @Published var scale: CGFloat = 1.0
    @Published var doublePaged: Bool = false
    @Published var lastPageOffsetPCT: Double? = nil
    
    let book: CompleteBook
    
    init(book: CompleteBook) {
        self.book = book
        print("Inicializando ComicViewerModel para: \(book.book.title)")
    }
    
    func loadPages() {
        guard let url = book.metadata.localURL else {
            print("Error: URL local no disponible")
            isLoading = false
            return
        }
        
        print("Cargando cómic desde: \(url.path)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let loadedPages = ArchiveHelper.loadImages(from: url, type: self.book.book.type)
            
            DispatchQueue.main.async {
                self.pages = loadedPages
                self.totalPages = loadedPages.count
                
                // Establecer la página inicial basada en el progreso guardado
                if self.book.book.progress > 0 && self.totalPages > 0 {
                    let calculatedPage = Int(Double(self.totalPages - 1) * self.book.book.progress)
                    self.currentPage = max(0, min(calculatedPage, self.totalPages - 1))
                    
                    // Si es un webtoon, podríamos restaurar la posición vertical dentro de la página
                    // Esto se implementaría en el controlador de paginación
                    if self.readingMode.isVertical {
                        // Por ahora, simplemente establecemos un valor predeterminado
                        // En una implementación completa, esto se guardaría y recuperaría de la base de datos
                        self.lastPageOffsetPCT = 0.0
                    }
                    
                    print("Restaurando a la página \(self.currentPage + 1) de \(self.totalPages)")
                }
                
                self.isLoading = false
            }
        }
    }
    
    func saveProgress() -> CompleteBook? {
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
            lastReadDate: bookCopy.lastReadDate
        )
    }
    
    func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }
    
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
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
            // Fondo negro
            Color.black.edgesIgnoringSafeArea(.all)
            
            if model.isLoading {
                loadingView
            } else if !model.pages.isEmpty {
                ComicViewerContainer(model: model)
            } else {
                errorView
            }
            
            // Overlay de controles
            if model.showControls {
                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: model.showControls)
            }
        }
        .statusBar(hidden: !model.showControls)
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
                    onProgressUpdate?(updatedBook)
                    
                    // Notificar a la aplicación sobre el cambio en el progreso
                    NotificationCenter.default.post(
                        name: Notification.Name("BookProgressUpdated"),
                        object: nil,
                        userInfo: ["book": updatedBook]
                    )
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
            
            Text(model.book.book.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black, radius: 2, x: 0, y: 1)
            
            Spacer()
            
            Menu {
                Picker("Modo de Lectura", selection: $model.readingMode) {
                    ForEach(ReadingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Toggle("Páginas Dobles", isOn: $model.doublePaged)
                    .disabled(model.readingMode == .VERTICAL)
            } label: {
                Image(systemName: "gear")
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
                Text("\(model.currentPage + 1) de \(model.totalPages)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                
                Spacer()
                
                if let series = model.book.book.series {
                    Text(series)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                    
                    if let issue = model.book.book.issueNumber {
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
                        .frame(width: geometry.size.width * CGFloat(model.currentPage + 1) / CGFloat(model.totalPages), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Controles de navegación
            HStack(spacing: 40) {
                Button(action: {
                    model.previousPage()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(model.currentPage <= 0)
                .opacity(model.currentPage <= 0 ? 0.5 : 1.0)
                
                Button(action: {
                    model.nextPage()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(model.currentPage >= model.totalPages - 1)
                .opacity(model.currentPage >= model.totalPages - 1 ? 0.5 : 1.0)
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
    
    // Definir los layouts de regiones de navegación
    private let standardNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0, t: 0, r: 0.30, b: 1), type: .LEFT),
        .init(rect: .init(l: 0.69, t: 0, r: 1, b: 1), type: .RIGHT),
    ]
    
    private let lNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0.0, t: 0.33, r: 0.33, b: 0.66), type: .LEFT),
        .init(rect: .init(l: 0.0, t: 0.0, r: 1.0, b: 0.33), type: .LEFT),
        .init(rect: .init(l: 0.66, t: 0.33, r: 1.0, b: 0.66), type: .RIGHT),
        .init(rect: .init(l: 0.0, t: 0.66, r: 1.0, b: 1.0), type: .RIGHT),
    ]
    
    // Configuración actual de navegación
    private var currentNavigationRegions: [NavigationRegion] {
        return standardNavigationRegions
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
    }
    
    private func setupCollectionView() {
        // Crear el layout según el modo de lectura
        layout = createLayout()
        
        // Configurar el collection view
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInsetAdjustmentBehavior = .never
        
        // Registrar la celda
        collectionView.register(ComicPageCell.self, forCellWithReuseIdentifier: "PageCell")
        
        // Añadir a la vista
        view.addSubview(collectionView)
        
        // Configurar constraints
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
                guard let self = self else { return }
                self.scrollToPage(page)
            }
            .store(in: &cancellables)
        
        model.$readingMode
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateReadingMode()
            }
            .store(in: &cancellables)
        
        model.$doublePaged
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateReadingMode()
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
            if let pageCell = cell as? ComicPageCell,
               let doubleTapGesture = pageCell.scrollView?.doubleTapGesture {
                tapGestureRecognizer.require(toFail: doubleTapGesture)
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
        let action = getNavigationAction(for: location)
        handleNavigationAction(action)
    }
    
    private func getNavigationAction(for point: CGPoint) -> NavigationRegion.NavigationType {
        // Determinar en qué región se tocó
        for region in currentNavigationRegions {
            if region.rect.rect(for: view.bounds.size).contains(point) {
                return adjustActionForReadingMode(region.type)
            }
        }
        
        // Si no está en ninguna región definida, mostrar/ocultar el menú
        return .MENU
    }
    
    private func adjustActionForReadingMode(_ action: NavigationRegion.NavigationType) -> NavigationRegion.NavigationType {
        // Ajustar la acción según el modo de lectura (invertir para manga)
        if model.readingMode.isInverted {
            switch action {
            case .LEFT:
                return .RIGHT
            case .RIGHT:
                return .LEFT
            default:
                return action
            }
        }
        return action
    }
    
    private func handleNavigationAction(_ action: NavigationRegion.NavigationType) {
        switch action {
        case .MENU:
            model.showControls.toggle()
        case .LEFT:
            model.previousPage()
        case .RIGHT:
            model.nextPage()
        }
    }
    
    func updateReadingMode() {
        // Actualizar el layout
        let newLayout = createLayout()
        collectionView.setCollectionViewLayout(newLayout, animated: true)
        
        // Actualizar la transformación
        setReadingOrder()
        
        // Volver a cargar los datos
        collectionView.reloadData()
        
        // Actualizar los gestos
        updateGestureRecognizers()
        
        // Desplazarse a la página actual
        scrollToPage(model.currentPage)
    }
    
    private func createLayout() -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        
        if model.readingMode.isVertical {
            // Layout vertical para webtoons
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            layout.itemSize = CGSize(width: view.bounds.width, height: view.bounds.height)
        } else {
            // Layout horizontal para cómics/manga
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            
            if model.doublePaged && view.bounds.width > view.bounds.height {
                // Modo de página doble para dispositivos en landscape
                layout.itemSize = CGSize(width: view.bounds.width / 2, height: view.bounds.height)
            } else {
                // Modo de página única
                layout.itemSize = CGSize(width: view.bounds.width, height: view.bounds.height)
            }
        }
        
        return layout
    }
    
    private func setReadingOrder() {
        guard !model.readingMode.isVertical else {
            // No aplicar transformación para modo vertical
            collectionView.transform = .identity
            return
        }
        
        // Aplicar transformación para manga (derecha a izquierda)
        collectionView.transform = model.readingMode.isInverted ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }
    
    private func scrollToPage(_ page: Int) {
        guard page >= 0 && page < model.pages.count else { return }
        
        let indexPath = IndexPath(item: page, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        
        // Si estamos en modo vertical y hay una posición guardada, restaurarla
        if model.readingMode.isVertical, let offset = model.lastPageOffsetPCT {
            // Esperar a que la celda esté disponible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                if let cell = self.collectionView.cellForItem(at: indexPath) as? ComicPageCell,
                   let scrollView = cell.scrollView {
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
        }
    }
}

// MARK: - Extensiones del Controlador de Paginación

extension IVPagingController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCell", for: indexPath) as! ComicPageCell
        
        // Configurar la celda con la imagen
        if indexPath.item < model.pages.count {
            let image = model.pages[indexPath.item]
            cell.configure(with: image, readingMode: model.readingMode)
            
            // Actualizar los gestos para esta celda
            if let doubleTapGesture = cell.scrollView?.doubleTapGesture {
                tapGestureRecognizer.require(toFail: doubleTapGesture)
            }
        }
        
        return cell
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Actualizar la página actual cuando el desplazamiento se detiene
        let pageWidth = scrollView.frame.width
        let pageHeight = scrollView.frame.height
        
        if model.readingMode.isVertical {
            // Cálculo para desplazamiento vertical
            let page = Int(floor(scrollView.contentOffset.y / pageHeight))
            if page != model.currentPage {
                model.currentPage = max(0, min(page, model.pages.count - 1))
                
                // Calcular la posición dentro de la página para webtoons
                if let cell = collectionView.cellForItem(at: IndexPath(item: model.currentPage, section: 0)) as? ComicPageCell {
                    updatePageOffset(for: cell)
                }
            }
        } else {
            // Cálculo para desplazamiento horizontal
            let page = Int(floor(scrollView.contentOffset.x / pageWidth))
            if page != model.currentPage {
                model.currentPage = max(0, min(page, model.pages.count - 1))
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
        guard let scrollView = cell.scrollView else { return }
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
            }
        }
    }
}

// MARK: - Celda para Página de Cómic

class ComicPageCell: UICollectionViewCell {
    var scrollView: ZoomingScrollView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Crear el scroll view con zoom
        scrollView = ZoomingScrollView(frame: contentView.bounds)
        contentView.addSubview(scrollView)
        
        // Configurar constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with image: UIImage, readingMode: ReadingMode) {
        // Aplicar transformación para manga si es necesario
        if readingMode.isInverted && !readingMode.isVertical {
            scrollView.transform = CGAffineTransform(scaleX: -1, y: 1)
        } else {
            scrollView.transform = .identity
        }
        
        // Configurar la imagen
        scrollView.display(image: image)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        scrollView.reset()
    }
}

// MARK: - ScrollView con Zoom

class ZoomingScrollView: UIScrollView {
    private var imageView: UIImageView!
    var doubleTapGesture: UITapGestureRecognizer!
    private var wrapper: UIView!
    private var postImageSetConstraints: [NSLayoutConstraint] = []
    
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
        backgroundColor = .black
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        decelerationRate = .fast
        delegate = self
        contentInsetAdjustmentBehavior = .never
        
        // Configurar zoom
        minimumZoomScale = 1.0
        maximumZoomScale = 3.0
        bouncesZoom = true
    }
    
    private func setupWrapper() {
        // Crear un contenedor que coincide con el tamaño de la pantalla
        wrapper = UIView(frame: .zero)
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wrapper)
        
        // El wrapper se ajustará al tamaño del scroll view
        NSLayoutConstraint.activate([
            wrapper.centerYAnchor.constraint(equalTo: centerYAnchor),
            wrapper.heightAnchor.constraint(equalTo: heightAnchor)
        ])
    }
    
    private func setupImageView() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
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
        // Configurar la imagen
        imageView.image = image
        
        // Resetear el zoom
        zoomScale = 1.0
        
        // Limpiar restricciones anteriores
        NSLayoutConstraint.deactivate(postImageSetConstraints)
        postImageSetConstraints.removeAll()
        
        // Actualizar el frame de la imagen
        didUpdateSize(size: image.size)
    }
    
    func reset() {
        // Limpiar la imagen y resetear el zoom
        imageView.image = nil
        zoomScale = 1.0
        
        // Limpiar restricciones
        NSLayoutConstraint.deactivate(postImageSetConstraints)
        postImageSetConstraints.removeAll()
    }
    
    func didUpdateSize(size: CGSize) {
        // Centra la imagen en el wrapper
        postImageSetConstraints.append(contentsOf: [
            imageView.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])
        
        // Ajusta el tamaño según si es más ancho o alto que la vista
        if size.width <= frame.width {
            postImageSetConstraints.append(contentsOf: [
                wrapper.centerXAnchor.constraint(equalTo: centerXAnchor),
                wrapper.widthAnchor.constraint(equalTo: widthAnchor),
            ])
        } else {
            let ratio = size.width / size.height
            let targetHeight = frame.width / ratio
            
            postImageSetConstraints.append(contentsOf: [
                wrapper.centerXAnchor.constraint(equalTo: centerXAnchor),
                wrapper.widthAnchor.constraint(equalTo: widthAnchor),
            ])
        }
        
        // Configura el tamaño de la imagen
        let widthRatio = frame.width / size.width
        let heightRatio = frame.height / size.height
        let minRatio = min(widthRatio, heightRatio)
        
        postImageSetConstraints.append(contentsOf: [
            imageView.widthAnchor.constraint(equalToConstant: size.width * minRatio),
            imageView.heightAnchor.constraint(equalToConstant: size.height * minRatio)
        ])
        
        // Activa las restricciones
        NSLayoutConstraint.activate(postImageSetConstraints)
        
        // Actualiza el contenido del scroll view
        contentSize = wrapper.frame.size
        
        // Establece la posición inicial del zoom
        setZoomPosition()
    }
    
    func setZoomPosition() {
        guard contentSize.width > frame.width else {
            return
        }
        
        // Ajustar la posición según la dirección de lectura (RTL o LTR)
        // Por defecto, no hacemos nada para LTR
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        handleZoom(to: location, animated: true)
    }
    
    func handleZoom(to point: CGPoint, animated: Bool) {
        let currentScale = zoomScale
        let minScale = minimumZoomScale
        let maxScale = maximumZoomScale
        
        if minScale == maxScale, minScale > 1 {
            return
        }
        
        let toScale = maxScale
        let finalScale = (currentScale == minScale) ? toScale : minScale
        let zoomRect = zoomRectForScale(scale: finalScale, center: point)
        zoom(to: zoomRect, animated: animated)
    }
    
    func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = frame.size.height / scale
        zoomRect.size.width = frame.size.width / scale
        let newCenter = convert(center, from: self)
        zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Actualizar el contenido cuando cambia el tamaño
        if let image = imageView.image {
            didUpdateSize(size: image.size)
        }
    }
}

// Extensión para implementar el delegado de UIScrollView
extension ZoomingScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return wrapper
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Centrar el contenido cuando se hace zoom
        let offsetX = max((bounds.width - contentSize.width) * 0.5, 0)
        let offsetY = max((bounds.height - contentSize.height) * 0.5, 0)
        contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
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