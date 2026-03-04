//
//  HomeView.swift
//

import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import XMLCoder
import Combine
import Unrar
import Foundation
import UIKit
import CoreGraphics
import BackgroundTasks
import AVFoundation

// Definir alias para evitar ambigüedades
typealias ZipArchive = ZIPFoundation.Archive
typealias RarArchive = Unrar.Archive
typealias BookCollection = Collection

enum SortOption: String, CaseIterable, Identifiable {
    case intelligent = "Auto"
    case alphabeticalAsc = "A-Z"
    case alphabeticalDesc = "Z-A"
    case importDate = "Fecha de importación"
    
    var id: String { self.rawValue }
}

class HomeViewModel: ObservableObject {
    @Published var books: [CompleteBook] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @AppStorage("selectedCategory") var storedCategory: String = BookCategory.all.rawValue
    @Published var selectedCategory: BookCategory = .all
    @Published var isImporting: Bool = false
    @Published var isProcessingFiles: Bool = false // Nueva variable para controlar el estado de carga
    @AppStorage("gridLayout") var storedGridLayout: Int = 0
    @Published var gridLayout: Int = 0 // 0: Default, 1: List, 2: Large
    @AppStorage("isHeaderCompact") var storedIsHeaderCompact: Bool = false
    @Published var isHeaderCompact: Bool = false // Variable para controlar si el encabezado está compacto
    @Published var collectionsViewModel = CollectionsViewModel() // Agregamos el ViewModel de colecciones
    
    // Para controlar la actualización del encabezado
    @Published var headerRefreshTrigger: UUID = UUID()
    
    // Configuración de las secciones del Home
    @AppStorage("showRecentSection") var showRecentSection: Bool = true
    @AppStorage("showCollectionsSection") var showCollectionsSection: Bool = true
    
    // Toast notification state
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastStyle: ToastStyle = .success
    
    @AppStorage("books") private var storedBooksData: Data? // Persistencia con AppStorage
    
    enum BookCategory: String, CaseIterable, Identifiable {
        case all = "Todos"
        case books = "Libros"
        case comics = "Comics"
        case favorites = "Favoritos"

        var id: String { self.rawValue }
    }
    
    @AppStorage("selectedSortOption") var storedSortOption: String = SortOption.intelligent.rawValue
    
    // Almacenamiento de libros filtrados para evitar múltiples recálculos
    @Published private(set) var filteredBooks: [CompleteBook] = []
    
    // Separamos el sort option para evitar que provoque actualizaciones en la vista
    private var _selectedSortOption: SortOption = .intelligent
    var selectedSortOption: SortOption {
        get { _selectedSortOption }
        set {
            if _selectedSortOption != newValue {
                // Guardamos la categoría actual
                let currentCategory = selectedCategory
                
                _selectedSortOption = newValue
                // Actualizamos solo los libros filtrados sin emitir cambios en otras propiedades
                updateFilteredBooks()
                
                // Guardamos la nueva opción de ordenamiento
                storedSortOption = newValue.rawValue
                
                // Refrescar el encabezado para evitar problemas visuales
                refreshHeader()
                
                // Nos aseguramos de mantener la categoría seleccionada
                if selectedCategory != currentCategory {
                    updateSelectedCategory(currentCategory)
                }
            }
        }
    }
    
    // Cancellables para gestionar suscripciones
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadBooks()
        
        // Asegurarse de que el CollectionsViewModel tenga los libros actualizados
        collectionsViewModel.loadAvailableBooks()
        
        // Inicializar el ordenamiento desde el almacenamiento
        _selectedSortOption = SortOption(rawValue: storedSortOption) ?? .intelligent
        
        // Inicializar la categoría desde el almacenamiento
        print("Cargando categoría almacenada: \(storedCategory)")
        if let category = BookCategory(rawValue: storedCategory) {
            selectedCategory = category
            print("Categoría inicializada a: \(category.rawValue)")
        } else {
            selectedCategory = .all
            print("Categoría inicializada al valor por defecto: all")
        }
        
        // Inicializar el modo de vista desde el almacenamiento
        gridLayout = storedGridLayout
        print("Modo de vista inicializado a: \(gridLayout)")
        
        // Registrar observador para actualizaciones de progreso
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BookProgressUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let updatedBook = notification.userInfo?["book"] as? CompleteBook {
                print("Notificación recibida para actualizar progreso de: \(updatedBook.book.title) - \(updatedBook.book.progress * 100)%")
                self.updateBookProgress(updatedBook)
            } else {
                print("Error: No se pudo obtener el libro de la notificación")
            }
        }

        // Notificar al CollectionsViewModel cuando los libros se actualicen
        $books
            .sink { [weak self] _ in
                NotificationCenter.default.post(name: Notification.Name("BooksUpdated"), object: nil)
            }
            .store(in: &cancellables)

        // Sincronizar gridLayout con storedGridLayout
        $gridLayout
            .sink { [weak self] newValue in
                self?.storedGridLayout = newValue
            }
            .store(in: &cancellables)

        // Inicializar el estado del header desde el almacenamiento
        isHeaderCompact = storedIsHeaderCompact
        
        // Inicializar los libros filtrados
        updateFilteredBooks()
        
        // Crear combinación de publicadores para actualizar los filtros cuando cambian los criterios de filtrado
        Publishers.CombineLatest3($books, $searchText, $selectedCategory)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main) // Pequeño debounce para evitar múltiples actualizaciones
            .sink { [weak self] _, _, _ in
                self?.updateFilteredBooks()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Método para actualizar la lista filtrada de libros
    private func updateFilteredBooks() {
        var filtered = books

        if !searchText.isEmpty {
            filtered = filtered.filter { $0.displayTitle.lowercased().contains(searchText.lowercased()) ||
                                             $0.book.author.lowercased().contains(searchText.lowercased()) }
        }

        switch selectedCategory {
        case .all:
            break
        case .books:
            filtered = filtered.filter { $0.book.type == .epub || $0.book.type == .pdf || $0.book.type == .m4b }
        case .comics:
            filtered = filtered.filter { $0.book.type == .cbz || $0.book.type == .cbr }
        case .favorites:
            filtered = filtered.filter { $0.book.isFavorite }
        }
        
        // Apply sorting
        switch _selectedSortOption {
        case .alphabeticalAsc:
            filtered.sort { (book1: CompleteBook, book2: CompleteBook) in
                book1.displayTitle.localizedCompare(book2.displayTitle) == .orderedAscending
            }
        case .alphabeticalDesc:
            filtered.sort { (book1: CompleteBook, book2: CompleteBook) in
                book1.displayTitle.localizedCompare(book2.displayTitle) == .orderedDescending
            }
        case .importDate:
            filtered.sort { (book1: CompleteBook, book2: CompleteBook) in
                book1.book.lastReadDate ?? Date.distantPast > book2.book.lastReadDate ?? Date.distantPast
            }
        case .intelligent:
            filtered.sort { (book1: CompleteBook, book2: CompleteBook) in
                // 1. Priorizar favoritos
                if book1.book.isFavorite != book2.book.isFavorite {
                    return book1.book.isFavorite
                }
                
                // 2. Priorizar libros en progreso (entre 0% y 100%)
                let progress1 = book1.book.progress
                let progress2 = book2.book.progress
                if progress1 > 0 && progress1 < 1 && (progress2 == 0 || progress2 == 1) {
                    return true
                }
                if progress2 > 0 && progress2 < 1 && (progress1 == 0 || progress1 == 1) {
                    return false
                }
                
                // 3. Priorizar por fecha de última lectura
                let date1 = book1.book.lastReadDate ?? Date.distantPast
                let date2 = book2.book.lastReadDate ?? Date.distantPast
                if date1 != date2 {
                    return date1 > date2
                }
                
                // 4. Ordenar por serie y número si aplica
                let series1 = extractSeriesInfo(from: book1.book.title.lowercased())
                let series2 = extractSeriesInfo(from: book2.book.title.lowercased())
                
                if series1.name == series2.name {
                    return series1.number < series2.number
                }
                
                // 5. Si no hay otros criterios, ordenar alfabéticamente
                return book1.book.title.localizedCompare(book2.book.title) == .orderedAscending
            }
        }
        
        // Actualizamos la lista filtrada
        self.filteredBooks = filtered
    }

    var booksInProgress: [CompleteBook] {
        // Ordenar por fecha de última lectura (más reciente primero)
        return books.filter { $0.book.progress > 0 }.sorted { 
            guard let date1 = $0.book.lastReadDate else { return false }
            guard let date2 = $1.book.lastReadDate else { return true }
            return date1 > date2
        }
    }
    
    // Función para procesar un archivo importado
    func processImportedFile(url: URL) {
        print("Procesando archivo importado: \(url.path)")
        isProcessingFiles = true // Activar el indicador de carga
        
        // Asegurarse de que el LoadingManager esté activo
        if !LoadingManager.shared.isLoading {
            DispatchQueue.main.async {
                LoadingManager.shared.startLoading() // Activar la vista de carga global
                print("🔄 Activando indicador de carga global")
            }
        }
        
        // Primero, crear una copia permanente del archivo en el directorio de documentos de la app
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Crear un nombre único para el archivo
        let fileName = UUID().uuidString + "-" + url.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            // Si el archivo ya existe, eliminarlo primero
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // En iOS, necesitamos acceder al archivo de manera segura
            // Primero, verificar si el archivo tiene acceso de seguridad
            if url.startAccessingSecurityScopedResource() {
                defer {
                    // Asegurarse de liberar el acceso al archivo cuando terminemos
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Intentar leer el archivo como datos y luego escribirlo en la nueva ubicación
                do {
                    let data = try Data(contentsOf: url)
                    try data.write(to: destinationURL)
                    print("Archivo copiado correctamente a: \(destinationURL.path)")
                } catch {
                    print("Error al leer/escribir el archivo: \(error)")
                    // No desactivamos los indicadores de carga aquí para permitir que el proceso principal lo haga
                    return
                }
            } else {
                // Si no podemos acceder al archivo de manera segura, intentar copiarlo directamente
                try fileManager.copyItem(at: url, to: destinationURL)
                print("Archivo copiado directamente a: \(destinationURL.path)")
            }
            
            // Ahora procesar el archivo copiado
            let fileExtension = url.pathExtension.lowercased()
            switch fileExtension {
            case "cbz", "cbr":
                processComicBookFile(url: destinationURL, type: (fileExtension == "cbz" ? .cbz : .cbr))
            case "epub":
                processEpubFile(url: destinationURL)
            case "m4b":
                processM4BFile(url: destinationURL)
            default:
                // Para otros tipos de archivo, crearemos un nuevo Book con información básica
                // Limpiar el nombre del archivo eliminando el prefijo UUID
                let originalFileName = destinationURL.lastPathComponent
                let cleanFileName = originalFileName.replacingOccurrences(
                    of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
                    with: "",
                    options: .regularExpression
                )
                
                let newBook = CompleteBook(title: cleanFileName, author: "Desconocido", coverImage: "", type: getBookType(for: url), progress: 0.0, localURL: destinationURL)
                addBook(newBook)
            }
            
            // Guardar los cambios inmediatamente
            saveBooks()
            // No desactivamos los indicadores de carga aquí para permitir que el proceso principal lo haga
            
        } catch {
            print("Error al copiar el archivo: \(error)")
            // No desactivamos los indicadores de carga aquí para permitir que el proceso principal lo haga
            
            // Intentar un método alternativo si el primero falla
            do {
                let data = try Data(contentsOf: url)
                try data.write(to: destinationURL)
                print("Archivo copiado usando método alternativo a: \(destinationURL.path)")
                
                // Procesar el archivo copiado
                let fileExtension = url.pathExtension.lowercased()
                switch fileExtension {
                case "cbz", "cbr":
                    processComicBookFile(url: destinationURL, type: (fileExtension == "cbz" ? .cbz : .cbr))
                case "epub":
                    processEpubFile(url: destinationURL)
                case "m4b":
                    processM4BFile(url: destinationURL)
                default:
                    // Limpiar el nombre del archivo eliminando el prefijo UUID
                    let originalFileName = destinationURL.lastPathComponent
                    let cleanFileName = originalFileName.replacingOccurrences(
                        of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
                        with: "",
                        options: .regularExpression
                    )
                    
                    let newBook = CompleteBook(title: cleanFileName, author: "Desconocido", coverImage: "", type: getBookType(for: url), progress: 0.0, localURL: destinationURL)
                    addBook(newBook)
                }
                
                // Guardar los cambios inmediatamente
                saveBooks()
                // No desactivamos los indicadores de carga aquí para permitir que el proceso principal lo haga
            } catch {
                print("Error en el método alternativo: \(error)")
                // No desactivamos los indicadores de carga aquí para permitir que el proceso principal lo haga
            }
        }
    }
    
    // Función para extraer metadatos de un cómic
    func processComicBookFile(url: URL, type: BookType) {
        print("Procesando cómic: \(url.lastPathComponent)")
        print("Tipo de archivo: \(type.rawValue)")
        
        var coverImage: UIImage?
        var author: String = "Desconocido"
        var series: String? = nil
        var issueNumber: Int? = nil
        
        // Limpiar el nombre del archivo eliminando el prefijo UUID
        let originalFileName = url.lastPathComponent
        var title = originalFileName.replacingOccurrences(
            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
            with: "",
            options: .regularExpression
        )
        
        print("Nombre limpio: \(title)")
        
        // Obtener el controlador adecuado según el tipo de archivo
        let controller = ArchiveHelper.getController(for: type)
        
        do {
            // Intentar obtener la portada usando el controlador
            print("Obteniendo portada usando ArchiveHelper")
            coverImage = try controller.getThumbnailImage(for: url)
            print("Portada obtenida correctamente")
            
            // Intentar obtener metadatos ComicInfo.xml si existe
            if let comicInfoData = try controller.getComicInfo(for: url) {
                print("ComicInfo.xml encontrado, extrayendo metadatos")
                
                // Usar XMLParser para procesar los metadatos
                let comicInfoHandler = ComicInfoHandler()
                let parser = XMLParser(data: comicInfoData)
                parser.delegate = comicInfoHandler
                
                if parser.parse() {
                    if let comicTitle = comicInfoHandler.title, !comicTitle.isEmpty {
                        // Actualizar el título solo si se encontró uno en los metadatos
                        title = comicTitle
                        print("Título encontrado en metadatos: \(title)")
                    }
                    
                    if let comicSeries = comicInfoHandler.series, !comicSeries.isEmpty {
                        series = comicSeries
                        print("Serie encontrada: \(series ?? "Desconocida")")
                    }
                    
                    if let numberStr = comicInfoHandler.number, let number = Int(numberStr) {
                        issueNumber = number
                        print("Número encontrado: \(number)")
                    }
                    
                    if let comicWriter = comicInfoHandler.writer, !comicWriter.isEmpty {
                        author = comicWriter
                        print("Autor encontrado: \(author)")
                    }
                }
            }
        } catch {
            print("Error al procesar el archivo con ArchiveHelper: \(error)")
            
            // Si falla, intentar métodos alternativos específicos del tipo
            if type == .cbz {
                print("Intentando método alternativo para CBZ: \(url.path)")
                if let archive = ZipArchive(url: url, accessMode: .read) {
                    // Extraer portada
                    coverImage = extractCoverFromZip(archive: archive)
                    
                    // Extraer metadatos si existen
                    extractComicInfoFromZip(archive: archive, url: url, title: &title, author: &author, series: &series, issueNumber: &issueNumber)
                }
            } else if type == .cbr {
                print("Intentando método alternativo para CBR: \(url.path)")
                do {
                    let archive = try RarArchive(path: url.path, password: nil)
                    
                    // Extraer portada
                    coverImage = try extractCoverFromRar(archive: archive)
                    
                    // Extraer metadatos si existen
                    extractComicInfoFromRar(archive: archive, url: url, title: &title, author: &author, series: &series, issueNumber: &issueNumber)
                } catch {
                    print("Error al abrir archivo RAR: \(error)")
                }
            }
        }
        
        // Continuar con el procesamiento del cómic
        // Crear un nuevo libro con los metadatos extraídos
        var newBook = CompleteBook(
            title: title,
            author: author,
            coverImage: "",
            type: type,
            progress: 0.0,
            localURL: url,
            cover: coverImage
        )
        
        // Añadir metadatos adicionales si están disponibles
        var updatedBookCopy = newBook.book
        updatedBookCopy.series = series
        updatedBookCopy.issueNumber = issueNumber
        
        // Crear una nueva instancia que combine todos los datos actualizados
        newBook = CompleteBook(
            id: newBook.id,
            title: updatedBookCopy.title,
            author: updatedBookCopy.author,
            coverImage: updatedBookCopy.coverImage,
            type: updatedBookCopy.type,
            progress: updatedBookCopy.progress,
            localURL: url,
            cover: coverImage,
            lastReadDate: updatedBookCopy.lastReadDate
        )
        
        addBook(newBook)
        saveBooks() // Guardar inmediatamente después de añadir
    }
    
    // Función para extraer ComicInfo.xml de un archivo ZIP
    func extractComicInfoFromZip(archive: ZipArchive, url: URL, title: inout String, author: inout String, series: inout String?, issueNumber: inout Int?) {
        for entry in archive {
            if entry.path.lowercased().contains("comicinfo.xml") {
                do {
                    var data = Data()
                    try archive.extract(entry) { data.append($0) }
                    
                    // Usar XMLParser en lugar de XMLDocument
                    let comicInfoHandler = ComicInfoHandler()
                    let parser = XMLParser(data: data)
                    parser.delegate = comicInfoHandler
                    
                    if parser.parse() {
                        if let comicTitle = comicInfoHandler.title, !comicTitle.isEmpty {
                            title = comicTitle
                            print("Título encontrado: \(title)")
                        }
                        
                        if let comicSeries = comicInfoHandler.series, !comicSeries.isEmpty {
                            series = comicSeries
                            print("Serie encontrada: \(series ?? "Desconocida")")
                        }
                        
                        if let numberStr = comicInfoHandler.number, let number = Int(numberStr) {
                            issueNumber = number
                            print("Número encontrado: \(number)")
                        }
                        
                        if let comicWriter = comicInfoHandler.writer, !comicWriter.isEmpty {
                            author = comicWriter
                            print("Autor encontrado: \(author)")
                        }
                    }
                } catch {
                    print("Error al extraer ComicInfo.xml: \(error)")
                }
                break
            }
        }
    }
    
    // Función para extraer ComicInfo.xml de un archivo RAR
    func extractComicInfoFromRar(archive: RarArchive, url: URL, title: inout String, author: inout String, series: inout String?, issueNumber: inout Int?) {
        do {
            let entries = try archive.entries()
            
            if let comicInfoEntry = entries.first(where: { !$0.directory && $0.fileName.lowercased().contains("comicinfo.xml") }) {
                print("ComicInfo.xml encontrado: \(comicInfoEntry.fileName)")
                
                let data = try archive.extract(comicInfoEntry)
                
                // Usar XMLParser en lugar de XMLDocument
                let comicInfoHandler = ComicInfoHandler()
                let parser = XMLParser(data: data)
                parser.delegate = comicInfoHandler
                
                if parser.parse() {
                    if let comicTitle = comicInfoHandler.title, !comicTitle.isEmpty {
                        title = comicTitle
                        print("Título encontrado: \(title)")
                    }
                    
                    if let comicSeries = comicInfoHandler.series, !comicSeries.isEmpty {
                        series = comicSeries
                        print("Serie encontrada: \(series ?? "Desconocida")")
                    }
                    
                    if let numberStr = comicInfoHandler.number, let number = Int(numberStr) {
                        issueNumber = number
                        print("Número encontrado: \(number)")
                    }
                    
                    if let comicWriter = comicInfoHandler.writer, !comicWriter.isEmpty {
                        author = comicWriter
                        print("Autor encontrado: \(author)")
                    }
                }
            }
        } catch {
            print("Error al extraer ComicInfo.xml de RAR: \(error)")
        }
    }
    
    // Función para extraer la portada de un archivo ZIP
    func extractCoverFromZip(archive: ZipArchive) -> UIImage? {
        for entry in archive.sorted { $0.path < $1.path } {
            let entryPath = entry.path.lowercased()
            if entryPath.hasSuffix(".jpg") || entryPath.hasSuffix(".jpeg") || entryPath.hasSuffix(".png") {
                do {
                    print("Encontrada posible portada: \(entry.path)")
                    var data = Data()
                    try archive.extract(entry) { data.append($0) }
                    if let image = UIImage(data: data) {
                        print("Portada extraída correctamente")
                        return image
                    } else {
                        print("No se pudo crear la imagen desde los datos")
                    }
                    break
                } catch {
                    print("Error al extraer la portada: \(error)")
                }
            }
        }
        return nil
    }
    
    // Función para extraer la portada de un archivo RAR
    func extractCoverFromRar(archive: RarArchive) throws -> UIImage? {
        let entries = try archive.entries()
        
        let sortedEntries = entries
            .sorted(by: { $0.fileName < $1.fileName })
            .filter { !$0.directory && isImagePath($0.fileName) }
        
        if let firstImageEntry = sortedEntries.first {
            print("Portada encontrada en: \(firstImageEntry.fileName)")
            
            let data = try archive.extract(firstImageEntry)
            
            if let image = UIImage(data: data) {
                print("Portada extraída correctamente")
                return image
            } else {
                print("No se pudo crear la imagen desde los datos")
            }
        }
        
        return nil
    }
    
    // Función auxiliar para verificar si una ruta es una imagen
    func isImagePath(_ path: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        return imageExtensions.contains(pathExtension)
    }
    
    // Función para determinar el tipo de libro
    func getBookType(for url: URL) -> BookType {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "epub":
            return .epub
        case "pdf":
            return .pdf
        case "cbr":
            return .cbr
        case "cbz":
            return .cbz
        case "m4b":
            return .m4b
        default:
            return .epub // Tipo por defecto
        }
    }
    
    // Métodos para guardar y cargar los libros
    func saveBooks() {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(books)
            storedBooksData = encoded
            print("Libros guardados correctamente: \(books.count) libros")
            
            // Imprimir información de progreso para depuración
            for book in books where book.book.progress > 0 {
                print("Libro guardado: \(book.book.title) - Progreso: \(book.book.progress * 100)%")
            }
            
            // Forzar sincronización con UserDefaults
            UserDefaults.standard.synchronize()
            
            // Actualizar los libros disponibles en el CollectionsViewModel con un pequeño retraso
            // para asegurar que UserDefaults haya guardado los cambios
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.collectionsViewModel.loadAvailableBooks()
                
                // Notificar cambios en los libros para que se actualicen las colecciones
                NotificationCenter.default.post(name: Notification.Name("BooksUpdated"), object: nil)
                
                // Forzar la actualización de la vista
                self.objectWillChange.send()
            }
        } catch {
            print("Error al codificar los libros para guardar: \(error)")
        }
    }
    
    func loadBooks() {
        // Indicar que estamos cargando
        isLoading = true
        
        // Realizar la carga en un hilo en segundo plano
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let storedBooksData = self.storedBooksData {
                do {
                    let decoded = try JSONDecoder().decode([CompleteBook].self, from: storedBooksData)
                    
                    // Actualizar la UI en el hilo principal
                    DispatchQueue.main.async {
                        self.books = decoded
                        print("Libros cargados correctamente: \(self.books.count) libros")
                        
                        // Actualizar inmediatamente los libros filtrados
                        self.updateFilteredBooks()
                        
                        // Finalizar el estado de carga
                        self.isLoading = false
                        
                        // Verificar y reparar las rutas en segundo plano después de mostrar la UI
                        self.performPathRepairInBackground()
                    }
                } catch {
                    print("Error al decodificar los libros guardados: \(error)")
                    DispatchQueue.main.async {
                        self.loadSampleBooks()
                        self.isLoading = false
                    }
                }
            } else {
                print("No se encontraron libros guardados")
                DispatchQueue.main.async {
                    self.loadSampleBooks()
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadSampleBooks() {
        // Ya no cargamos libros de muestra, inicializamos un array vacío
        books = []
        print("Biblioteca inicializada sin libros de muestra")
    }
    
    // Función para verificar y reparar las rutas de los archivos
    func verifyAndRepairBookPaths() {
        let fileManager = FileManager.default
        var needsSaving = false
        
        print("Verificando y reparando rutas de archivos...")
        
        // Primero, regenerar todas las portadas de EPUBs
        print("Regenerando portadas de EPUBs...")
        for (index, book) in books.enumerated() {
            if book.book.type == .epub, 
               let url = book.metadata.localURL, 
               fileManager.fileExists(atPath: url.path) {
                print("Regenerando portada para: \(book.book.title)")
                
                if let coverImage = extractCoverFromFile(url: url, type: .epub) {
                    // Crear una nueva instancia que combine todos los datos actualizados
                    let updatedBook = CompleteBook(
                        id: book.id,
                        title: book.book.title,
                        author: book.book.author,
                        coverImage: book.book.coverImage,
                        type: book.book.type,
                        progress: book.book.progress,
                        localURL: url,
                        cover: coverImage,
                        lastReadDate: book.book.lastReadDate
                    )
                    books[index] = updatedBook
                    needsSaving = true
                    print("Portada regenerada para \(book.book.title)")
                } else {
                    print("No se pudo regenerar la portada para \(book.book.title)")
                }
            }
        }
        
        // Luego, verificar y reparar las rutas de archivos
        for (index, book) in books.enumerated() {
            // Verificar si la portada existe
            if let coverPath = book.metadata.coverPath {
                if !fileManager.fileExists(atPath: coverPath) {
                    print("Portada no encontrada para \(book.book.title): \(coverPath)")
                    
                    // Intentar regenerar la portada si es un cómic o EPUB
                    if (book.book.type == .cbz || book.book.type == .cbr || book.book.type == .epub), 
                       let url = book.metadata.localURL, 
                       fileManager.fileExists(atPath: url.path) {
                        print("Intentando regenerar portada desde: \(url.path)")
                        if let coverImage = extractCoverFromFile(url: url, type: book.book.type) {
                            // Crear una nueva instancia que combine todos los datos actualizados
                            let updatedBook = CompleteBook(
                                id: book.id,
                                title: book.book.title,
                                author: book.book.author,
                                coverImage: book.book.coverImage,
                                type: book.book.type,
                                progress: book.book.progress,
                                localURL: book.metadata.localURL,
                                cover: coverImage,
                                lastReadDate: book.book.lastReadDate
                            )
                            books[index] = updatedBook
                            needsSaving = true
                            print("Portada regenerada para \(book.book.title)")
                        } else {
                            print("No se pudo regenerar la portada para \(book.book.title)")
                        }
                    }
                } else {
                    print("Portada encontrada para \(book.book.title): \(coverPath)")
                }
            } else {
                print("No hay ruta de portada para \(book.book.title)")
                
                // Intentar generar una portada si no existe
                if (book.book.type == .cbz || book.book.type == .cbr || book.book.type == .epub), 
                   let url = book.metadata.localURL, 
                   fileManager.fileExists(atPath: url.path) {
                    print("Intentando generar portada desde: \(url.path)")
                    if let coverImage = extractCoverFromFile(url: url, type: book.book.type) {
                        // Crear una nueva instancia que combine todos los datos actualizados
                        let updatedBook = CompleteBook(
                            id: book.id,
                            title: book.book.title,
                            author: book.book.author,
                            coverImage: book.book.coverImage,
                            type: book.book.type,
                            progress: book.book.progress,
                            localURL: book.metadata.localURL,
                            cover: coverImage,
                            lastReadDate: book.book.lastReadDate
                        )
                        books[index] = updatedBook
                        needsSaving = true
                        print("Portada generada para \(book.book.title)")
                    }
                }
            }
            
            // Verificar si el archivo local existe
            if let localURL = book.metadata.localURL {
                if !fileManager.fileExists(atPath: localURL.path) {
                    print("Archivo no encontrado para \(book.book.title): \(localURL.path)")
                    // Aquí podrías implementar lógica adicional para manejar archivos faltantes
                } else {
                    print("Archivo encontrado para \(book.book.title): \(localURL.path)")
                    
                    // Limpiar el título si contiene un prefijo UUID
                    let currentTitle = book.book.title
                    if currentTitle.range(of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-", options: .regularExpression) != nil {
                        let cleanTitle = currentTitle.replacingOccurrences(
                            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
                            with: "",
                            options: .regularExpression
                        )
                        
                        print("Limpiando título: \(currentTitle) -> \(cleanTitle)")
                        
                        // En lugar de intentar modificar la propiedad title, creamos directamente un nuevo libro
                        let updatedBook = CompleteBook(
                            id: book.id,
                            title: cleanTitle,
                            author: book.book.author,
                            coverImage: book.book.coverImage,
                            type: book.book.type,
                            progress: book.book.progress,
                            localURL: book.metadata.localURL,
                            cover: book.getCoverImage(),
                            lastReadDate: book.book.lastReadDate
                        )
                        
                        books[index] = updatedBook
                        needsSaving = true
                        print("Título limpiado para \(cleanTitle)")
                    }
                }
            } else {
                print("No hay ruta de archivo para \(book.book.title)")
            }
        }
        
        // Guardar los cambios si se hicieron reparaciones
        if needsSaving {
            print("Guardando cambios después de reparaciones...")
            saveBooks()
        } else {
            print("No se necesitaron reparaciones")
        }
    }
    
    // Función para extraer la portada de un archivo (cómic o EPUB)
    func extractCoverFromFile(url: URL, type: BookType) -> UIImage? {
        print("Extrayendo portada de: \(url.path)")
        
        switch type {
        case .cbz, .cbr:
            return extractCoverFromComic(url: url, type: type)
        case .epub:
            do {
                let controller = EpubController()
                return try controller.getThumbnailImage(for: url)
            } catch {
                print("Error al extraer la portada del EPUB: \(error)")
                return nil
            }
        default:
            return nil
        }
    }
    
    // Función para extraer la portada de un cómic
    func extractCoverFromComic(url: URL, type: BookType) -> UIImage? {
        guard type == .cbz || type == .cbr else { return nil }
        
        print("Extrayendo portada de cómic: \(url.path)")
        
        // Limpiar el nombre del archivo eliminando el prefijo UUID
        let originalFileName = url.lastPathComponent
        let cleanFileName = originalFileName.replacingOccurrences(
            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
            with: "",
            options: .regularExpression
        )
        
        print("Nombre limpio: \(cleanFileName)")
        
        if type == .cbz {
            print("Procesando archivo CBZ: \(url.path)")
            // Usar el ArchiveHelper en lugar de acceder directamente al ZIP
            let controller = ArchiveHelper.getController(for: .cbz)
            do {
                return try controller.getThumbnailImage(for: url)
            } catch {
                print("Error al extraer portada de CBZ: \(error)")
                
                // Intento alternativo con ZipArchive directo si falla el controlador
                if let archive = ZipArchive(url: url, accessMode: .read) {
                    // Ordenar las entradas para asegurarnos de obtener la primera imagen
                    let sortedEntries = archive.sorted { $0.path < $1.path }
                    
                    for entry in sortedEntries {
                        let entryPath = entry.path.lowercased()
                        if entryPath.hasSuffix(".jpg") || entryPath.hasSuffix(".jpeg") || entryPath.hasSuffix(".png") {
                            do {
                                print("Encontrada posible portada: \(entry.path)")
                                var data = Data()
                                try archive.extract(entry) { data.append($0) }
                                if let image = UIImage(data: data) {
                                    print("Portada extraída correctamente")
                                    return image
                                } else {
                                    print("No se pudo crear la imagen desde los datos")
                                }
                                break
                            } catch {
                                print("Error al extraer la portada: \(error)")
                            }
                        }
                    }
                    print("No se encontraron imágenes en el archivo")
                }
            }
        } else if type == .cbr {
            do {
                print("Intentando abrir archivo RAR: \(url.path)")
                let archive = try RarArchive(path: url.path, password: nil)
                
                let entries = try archive.entries()
                print("Entradas encontradas: \(entries.count)")
                
                let sortedEntries = entries
                    .sorted(by: { $0.fileName < $1.fileName })
                    .filter { !$0.directory && isImagePath($0.fileName) }
                
                if let firstImageEntry = sortedEntries.first {
                    print("Portada encontrada en: \(firstImageEntry.fileName)")
                    
                    let data = try archive.extract(firstImageEntry)
                    
                    if let image = UIImage(data: data) {
                        print("Portada extraída correctamente")
                        return image
                    } else {
                        print("No se pudo crear la imagen desde los datos")
                    }
                } else {
                    print("No se encontraron imágenes en el archivo RAR")
                }
            } catch {
                print("Error al abrir archivo RAR: \(error)")
            }
        } else {
            print("Tipo de archivo no soportado: \(type.rawValue)")
            return nil
        }
        
        return nil
    }

    func addBook(_ book: CompleteBook) {
        books.append(book)
    }

    func deleteBook(book: CompleteBook) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books.remove(at: index)
            
            // Eliminar el libro de todas las colecciones que lo contengan
            for collection in collectionsViewModel.collections {
                if collection.books.contains(book.id) {
                    collectionsViewModel.removeBookFromCollection(collection, bookID: book.id)
                }
            }
            
            // Guardar cambios
            saveBooks()
            
            // Mostrar notificación toast
            self.toastMessage = "Título eliminado correctamente"
            self.toastStyle = .success
            
            // Usar withAnimation con un DispatchQueue para asegurar que se active el toast
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.showToast = true
                }
            }
        }
    }

    // Función para borrar todos los libros y cargar los de muestra
    func resetToSampleBooks() {
        // Primero forzar eliminación de colecciones en UserDefaults directamente
        UserDefaults.standard.removeObject(forKey: "collections")
        UserDefaults.standard.synchronize()
        
        // Borrar todos los libros
        books.removeAll()
        
        // Borrar los datos guardados
        storedBooksData = nil
        
        // Forzar eliminación en UserDefaults
        UserDefaults.standard.removeObject(forKey: "books")
        UserDefaults.standard.synchronize()
        
        // Resetear las colecciones - asegurarse que se ejecute en la cola principal
        DispatchQueue.main.async {
            // Limpiar completamente las colecciones
            self.collectionsViewModel.clearAllCollections()
            
            // Esperar un poco para asegurar que los cambios se procesen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Verificar que realmente se hayan eliminado
                if self.collectionsViewModel.collections.isEmpty {
                    print("Confirmado: las colecciones se han eliminado correctamente")
                } else {
                    print("⚠️ ADVERTENCIA: Las colecciones no se eliminaron correctamente")
                    // Intentar nuevamente
                    self.collectionsViewModel.clearAllCollections()
                }
                
                // Cargar los libros de muestra después de limpiar todo
                self.loadSampleBooks()
                
                // Guardar los cambios
                self.saveBooks()
                
                // Forzar actualización de la UI
                self.objectWillChange.send()
                self.collectionsViewModel.objectWillChange.send()
                
                print("Biblioteca reiniciada con libros de muestra y colecciones eliminadas")
            }
        }
    }

    // Función para actualizar el progreso de un libro
    func updateBookProgress(_ updatedBook: CompleteBook) {
        print("Actualizando progreso para libro: \(updatedBook.book.title)")
        print("Progreso recibido: \(updatedBook.book.progress * 100)%")
        
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            // Obtener el libro existente
            let existingBook = books[index]
            
            print("Libro encontrado en la colección en posición \(index)")
            print("Progreso anterior: \(existingBook.book.progress * 100)%")
            
            // Calcular la página actual de forma segura
            let currentPageText: String
            if let pageCount = updatedBook.book.pageCount {
                let currentPage = Int(Double(pageCount) * updatedBook.book.progress)
                currentPageText = String(currentPage)
            } else {
                currentPageText = "desconocida"
            }
            print("Página actual: \(currentPageText) de \(updatedBook.book.pageCount ?? 0)")
            
            // Crear una nueva instancia que combine todos los datos actualizados
            var updatedBookCopy = updatedBook.book
            updatedBookCopy.pageCount = updatedBook.book.pageCount
            
            // Preservar datos importantes del libro existente
            updatedBookCopy.series = existingBook.book.series
            updatedBookCopy.issueNumber = existingBook.book.issueNumber
            
            let combinedBook = CompleteBook(
                id: updatedBook.id,
                title: updatedBook.book.title,
                author: updatedBook.book.author,
                coverImage: updatedBook.book.coverImage,
                type: updatedBook.book.type,
                progress: updatedBook.book.progress,
                localURL: updatedBook.metadata.localURL,
                cover: updatedBook.getCoverImage() ?? existingBook.getCoverImage(),
                lastReadDate: updatedBook.book.lastReadDate,
                lastPageOffsetPCT: updatedBook.lastPageOffsetPCT,
                isFavorite: existingBook.book.isFavorite // Mantener el estado de favorito
            )
            
            // Actualizar el libro en la colección
            books[index] = combinedBook
            
            // Actualizar el libro en CollectionsViewModel
            DispatchQueue.main.async {
                self.collectionsViewModel.updateBookInCollections(combinedBook)
                self.saveBooks()
                // Forzar actualización de la UI
                self.objectWillChange.send()
                self.collectionsViewModel.objectWillChange.send()
                print("Progreso actualizado y guardado para \(combinedBook.book.title): \(combinedBook.book.progress * 100)%")
                print("Número de páginas actualizado: \(updatedBook.book.pageCount ?? 0)")
            }
        } else {
            print("No se encontró el libro con ID: \(updatedBook.id) - Añadiendo a la colección")
            // Si el libro no existe en la colección, añadirlo
            books.append(updatedBook)
            
            // Guardar los cambios inmediatamente y notificar la actualización UI
            DispatchQueue.main.async {
                self.saveBooks()
                // Forzar actualización de la UI
                self.objectWillChange.send()
                print("Nuevo libro añadido y guardado: \(updatedBook.book.title)")
            }
        }
    }

    // Función para procesar un archivo EPUB
    func processEpubFile(url: URL) {
        print("Procesando EPUB: \(url.lastPathComponent)")
        
        var coverImage: UIImage?
        var author: String = "Desconocido"
        
        // Limpiar el nombre del archivo eliminando el prefijo UUID
        let originalFileName = url.lastPathComponent
        let cleanFileName = originalFileName.replacingOccurrences(
            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
            with: "",
            options: .regularExpression
        )
        
        // Eliminar la extensión del archivo
        let fileNameWithoutExtension = cleanFileName.replacingOccurrences(
            of: "\\.epub$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        var title: String = fileNameWithoutExtension
        
        // Intentar extraer la portada usando el controlador de EPUB
        do {
            let controller = EpubController()
            coverImage = try controller.getThumbnailImage(for: url)
            print("Portada de EPUB extraída correctamente")
        } catch {
            print("Error al extraer la portada del EPUB: \(error)")
        }
        
        // Crear un nuevo libro con los metadatos extraídos
        let newBook = CompleteBook(
            title: title,
            author: author,
            coverImage: "",
            type: .epub,
            progress: 0.0,
            localURL: url,
            cover: coverImage
        )
        
        addBook(newBook)
        saveBooks() // Guardar inmediatamente después de añadir
    }
    
    // Función para procesar un archivo M4B
    func processM4BFile(url: URL) {
        print("Procesando M4B: \(url.lastPathComponent)")
        
        var coverImage: UIImage?
        var author: String = "Desconocido"
        
        // Limpiar el nombre del archivo eliminando el prefijo UUID
        let originalFileName = url.lastPathComponent
        let cleanFileName = originalFileName.replacingOccurrences(
            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
            with: "",
            options: .regularExpression
        )
        
        // Eliminar la extensión del archivo
        let fileNameWithoutExtension = cleanFileName.replacingOccurrences(
            of: "\\.m4b$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        var title: String = fileNameWithoutExtension
        
        // Intentar extraer metadatos y portada usando AVAsset
        let asset = AVAsset(url: url)
        
        // Extraer metadatos
        for item in asset.metadata {
            if let keySpace = item.keySpace, let key = item.key {
                print("Metadato encontrado: \(keySpace) - \(key)")
                
                // Comprobar metadatos comunes
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case AVMetadataKey.commonKeyTitle:
                        if let titleValue = item.stringValue {
                            title = titleValue
                            print("Título extraído: \(title)")
                        }
                    case AVMetadataKey.commonKeyArtist, AVMetadataKey.commonKeyAuthor:
                        if let artistValue = item.stringValue {
                            author = artistValue
                            print("Autor extraído: \(author)")
                        }
                    case AVMetadataKey.commonKeyArtwork:
                        if let artworkData = item.dataValue, let image = UIImage(data: artworkData) {
                            coverImage = image
                            print("Portada extraída de los metadatos")
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        // Si no se encontró portada, usar una imagen predeterminada para audiolibros
        if coverImage == nil {
            // Crear una imagen predeterminada para audiolibros
            let config = UIImage.SymbolConfiguration(pointSize: 150, weight: .regular)
            if let defaultImage = UIImage(systemName: "headphones.circle.fill", withConfiguration: config)?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal) {
                coverImage = defaultImage
                print("Usando portada predeterminada para audiolibro")
            }
        }
        
        // Crear un nuevo libro con los metadatos extraídos
        let newBook = CompleteBook(
            title: title,
            author: author,
            coverImage: "",
            type: .m4b,
            progress: 0.0,
            localURL: url,
            cover: coverImage
        )
        
        addBook(newBook)
        saveBooks() // Guardar inmediatamente después de añadir
    }
    
    // Función para actualizar el estado de favorito de un libro
    func toggleFavorite(book: CompleteBook) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            let updatedBook = book.withUpdatedFavorite(!book.book.isFavorite)
            books[index] = updatedBook
            saveBooks()
        }
    }

    // Función para actualizar la categoría seleccionada
    func updateSelectedCategory(_ category: BookCategory) {
        selectedCategory = category
        storedCategory = category.rawValue
        print("Categoría actualizada a: \(category.rawValue), almacenada como: \(storedCategory)")
        
        // Actualizar el encabezado para evitar problemas de visualización
        refreshHeader()
        
        // Si la nueva categoría es .all, forzar la actualización para que aparezcan las secciones
        if category == .all {
            // Forzar la recarga de colecciones
            collectionsViewModel.loadCollections()
            collectionsViewModel.loadAvailableBooks()
            
            // Forzar actualización de la vista
            objectWillChange.send()
        }
    }

    // Función para refrescar el encabezado
    func refreshHeader() {
        // Generar un nuevo UUID para forzar la reconstrucción del encabezado
        DispatchQueue.main.async {
            self.headerRefreshTrigger = UUID()
        }
    }

    private struct SeriesInfo {
        let name: String
        let number: Int
    }

    private func extractSeriesInfo(from title: String) -> SeriesInfo {
        // Regular expression to match patterns like "Series Name 01", "Series Name 1", etc.
        let pattern = #"(.+?)\s*(\d+)$"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
            let seriesName = String(title[Range(match.range(at: 1), in: title)!]).trimmingCharacters(in: .whitespaces)
            let numberStr = String(title[Range(match.range(at: 2), in: title)!])
            if let number = Int(numberStr) {
                return SeriesInfo(name: seriesName, number: number)
            }
        }
        
        // If no match found, return the title as the name and a high number to sort it at the end
        return SeriesInfo(name: title, number: Int.max)
    }

    // Nuevo método para realizar la verificación de rutas en segundo plano
    func performPathRepairInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            print("Verificando y reparando rutas de archivos en segundo plano...")
            let fileManager = FileManager.default
            var booksToUpdate: [(Int, CompleteBook)] = []
            
            // Verificación y reparación sin bloquear la UI
            for (index, book) in self.books.enumerated() {
                // Verificar si el archivo local existe
                if let localURL = book.metadata.localURL, fileManager.fileExists(atPath: localURL.path) {
                    var needsUpdate = false
                    var updatedBook = book
                    
                    // Limpiar el título si contiene un prefijo UUID (sin bloquear UI)
                    let currentTitle = book.book.title
                    if currentTitle.range(of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-", options: .regularExpression) != nil {
                        let cleanTitle = currentTitle.replacingOccurrences(
                            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
                            with: "",
                            options: .regularExpression
                        )
                        
                        print("Limpiando título: \(currentTitle) -> \(cleanTitle)")
                        
                        updatedBook = CompleteBook(
                            id: book.id,
                            title: cleanTitle,
                            author: book.book.author,
                            coverImage: book.book.coverImage,
                            type: book.book.type,
                            progress: book.book.progress,
                            localURL: book.metadata.localURL,
                            cover: book.getCoverImage(),
                            lastReadDate: book.book.lastReadDate
                        )
                        needsUpdate = true
                    }
                    
                    // Solo verificar las portadas si no existían previamente o si eran necesarias
                    if let coverPath = book.metadata.coverPath, !fileManager.fileExists(atPath: coverPath) {
                        if (book.book.type == .cbz || book.book.type == .cbr || book.book.type == .epub) {
                            if let coverImage = self.extractCoverFromFile(url: localURL, type: book.book.type) {
                                updatedBook = CompleteBook(
                                    id: book.id,
                                    title: updatedBook.book.title,
                                    author: book.book.author,
                                    coverImage: book.book.coverImage,
                                    type: book.book.type,
                                    progress: book.book.progress,
                                    localURL: book.metadata.localURL,
                                    cover: coverImage,
                                    lastReadDate: book.book.lastReadDate
                                )
                                needsUpdate = true
                            }
                        }
                    }
                    
                    if needsUpdate {
                        booksToUpdate.append((index, updatedBook))
                    }
                }
            }
            
            // Aplicar actualizaciones en el hilo principal
            if !booksToUpdate.isEmpty {
                DispatchQueue.main.async {
                    var updatedBooks = self.books
                    
                    for (index, book) in booksToUpdate {
                        if index < updatedBooks.count {
                            updatedBooks[index] = book
                        }
                    }
                    
                    self.books = updatedBooks
                    self.saveBooks()
                    
                    // Actualizar los filtros después de los cambios
                    self.updateFilteredBooks()
                }
            }
        }
    }
    
    // Método para realizar una actualización ligera sin bloquear la UI
    func performLightRefresh() {
        // Verificar si hay nuevos libros sin iniciar carga pesada
        print("Realizando actualización ligera")
        
        // No recargar los libros completos, solo actualizar los filtros
        DispatchQueue.main.async {
            // Cancelar cualquier procesamiento en curso
            self.isProcessingFiles = false
            self.isImporting = false
            
            // Actualizar solo si hay cambios
            self.updateFilteredBooks()
            
            // Actualizar el header
            self.refreshHeader()
            
            // Notificar cualquier cambio
            self.objectWillChange.send()
        }
    }
    
    // Restauración segura - Para usar cuando la app vuelve de segundo plano
    func safeRestoreFromBackground() {
        print("🔄 Restaurando HomeViewModel desde segundo plano")
        
        // Limpiar estados de carga
        isLoading = false
        isImporting = false
        isProcessingFiles = false
        isSearching = false
        
        // Actualizar la UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Solo actualizar los filtros, sin cargar datos pesados
            self.updateFilteredBooks()
            
            // Actualizar el header
            self.headerRefreshTrigger = UUID()
            
            // Notificar cambios
            self.objectWillChange.send()
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var scrollOffset: CGFloat = 0
    @State private var isInitialLoad = true
    @State private var showSkeleton = true
    @State private var isRestoringFromBackground = false
    @State private var uiBlockedTimer: Timer? = nil
    
    // Bindings externos para búsqueda desde el tab bar
    @Binding var externalSearchText: String
    @Binding var externalIsSearching: Bool
    
    init(externalSearchText: Binding<String> = .constant(""), externalIsSearching: Binding<Bool> = .constant(false)) {
        self._externalSearchText = externalSearchText
        self._externalIsSearching = externalIsSearching
    }
    
    var body: some View {
        ZStack {
            // Contenido principal
            mainContent
                
            // Toast notification - ahora en un ZStack separado con posición absoluta
            if viewModel.showToast {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: viewModel.toastStyle.iconName)
                                .foregroundColor(viewModel.toastStyle.iconColor)
                                .font(.system(size: 18))
                            
                            Text(viewModel.toastMessage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer(minLength: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appTheme().opacity(0.3), lineWidth: 1)
                        )
                        .frame(maxWidth: min(geometry.size.width - 80, 350))
                        .padding(.bottom, 64) // Posición fija desde la parte inferior de la pantalla
                    }
                    .position(x: geometry.size.width/2, y: geometry.size.height - 32)
                }
                .ignoresSafeArea()
                .zIndex(9999) // Asegurarse de que está por encima de todo
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.showToast)
                .onAppear {
                    // Aumentamos el tiempo de visualización a 2.5 segundos para dar más tiempo para leer
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            viewModel.showToast = false
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Iniciar el timer de seguridad para detectar bloqueos
            scheduleUIBlockRecoveryTimer()
        }
        .onDisappear {
            // Cancelar el timer cuando la vista desaparece
            uiBlockedTimer?.invalidate()
            uiBlockedTimer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppWillEnterForeground"))) { _ in
            // Marcar que estamos restaurando desde segundo plano
            isRestoringFromBackground = true
            
            // Asegurarse de que no estemos mostrando el esqueleto
            showSkeleton = false
            
            // Cancelar cualquier operación potencialmente bloqueante
            LoadingManager.shared.forceStopAllLoading()
            
            // Restaurar de forma segura
            viewModel.safeRestoreFromBackground()
            
            // Reiniciar el timer de seguridad
            scheduleUIBlockRecoveryTimer()
            
            // Liberar cualquier bloqueo de UI y refrescar datos si es necesario
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Forzar actualización de la UI
                withAnimation {
                    viewModel.refreshHeader()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppBecameActive"))) { _ in
            // Solo realizar operaciones adicionales si estamos volviendo desde segundo plano
            if isRestoringFromBackground {
                // Recargar datos en segundo plano sin bloquear la UI
                DispatchQueue.global(qos: .userInitiated).async {
                    viewModel.performLightRefresh()
                    
                    // Restablecer el estado
                    DispatchQueue.main.async {
                        isRestoringFromBackground = false
                    }
                }
            }
        }
    }
    
    // Función para programar el timer de seguridad
    private func scheduleUIBlockRecoveryTimer() {
        // Cancelar cualquier timer anterior
        uiBlockedTimer?.invalidate()
        
        // Crear un nuevo timer que verificará si la UI está bloqueada cada 3 segundos
        uiBlockedTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // Verificar si hay indicadores de carga activos por más tiempo del esperado
            if LoadingManager.shared.isLoading {
                print("⚠️ Posible bloqueo de UI detectado - realizando recuperación automática")
                
                // Forzar la liberación de todos los bloqueos de carga
                LoadingManager.shared.forceStopAllLoading()
                
                // Ocultar esqueleto si estuviera visible
                if self.showSkeleton {
                    DispatchQueue.main.async {
                        withAnimation {
                            self.showSkeleton = false
                        }
                    }
                }
                
                // Forzar actualización de la UI
                DispatchQueue.main.async {
                    withAnimation {
                        self.viewModel.refreshHeader()
                    }
                }
            }
        }
    }
    
    // Vista principal
    private var mainContent: some View {
        NavigationView {
            contentView
                .navigationTitle("Biblioteca")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            viewModel.isImporting = true
                        }) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.appTheme())
                        }
                    }
                }
                .onChange(of: externalSearchText) { newValue in
                    viewModel.searchText = newValue
                    viewModel.isSearching = !newValue.isEmpty || externalIsSearching
                }
                .onChange(of: externalIsSearching) { newValue in
                    viewModel.isSearching = newValue || !externalSearchText.isEmpty
                }
                .onChange(of: viewModel.searchText) { newValue in
                    if externalSearchText != newValue {
                        externalSearchText = newValue
                    }
                }
                .onAppear {
                    print("⭐️ Home view appeared")
                    
                    // Inicialización diferida
                    if isInitialLoad {
                        // Cargar libros inmediatamente (ya optimizado para carga en segundo plano)
                        viewModel.loadBooks()
                        
                        // Mostrar el esqueleto por un mínimo de tiempo (mejor UX)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation {
                                showSkeleton = false
                            }
                        }
                        
                        // Diferir la carga de colecciones para después de que se muestre la UI
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.collectionsViewModel.loadCollections()
                            viewModel.collectionsViewModel.loadAvailableBooks()
                            
                            // Asegurarnos de que el gridLayout refleja el valor almacenado
                            viewModel.gridLayout = viewModel.storedGridLayout
                            
                            // Forzar actualización del encabezado en un momento posterior
                            viewModel.refreshHeader()
                        }
                        
                        isInitialLoad = false
                    } else {
                        // Si no es la carga inicial, mostrar contenido inmediatamente
                    showSkeleton = false
                }
                
                // Asegurarnos de que la categoría es all
                if viewModel.selectedCategory != .all {
                    viewModel.updateSelectedCategory(.all)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Usar StackNavigationViewStyle para evitar problemas de transición
    }
    
    // Vista de contenido real
    private var contentView: some View {
        ScrollView {
            // Contenido principal
            VStack(alignment: .leading, spacing: 0) {
                // Espacio adicional para alinear con el botón
                Color.clear.frame(height: 8)
                
                // Sección de "Continuar leyendo"
                ContinueReadingSection(viewModel: viewModel)
                
                // Sección de "Tus colecciones"
                coleccionesSection
                    .padding(.bottom, 0)
                    .padding(.top, 0)
                
                // Sección de "Todos los libros"
                todosLibrosSection
                    .padding(.top, 0)
                    .padding(.bottom, 0)

                Spacer(minLength: 120)
            }
        }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: [UTType.pdf, UTType.epub, UTType.init(filenameExtension: "cbr")!, UTType.init(filenameExtension: "cbz")!, UTType.init(filenameExtension: "m4b")!],
            allowsMultipleSelection: true
        ) { result in
            // Activar el indicador de carga antes de comenzar el proceso de selección
            viewModel.isProcessingFiles = true
            LoadingManager.shared.startLoading()
            
            switch result {
            case .success(let urls):
                // Procesar todas las URLs seleccionadas
                DispatchQueue.global(qos: .userInitiated).async {
                    for (index, url) in urls.enumerated() {
                        print("🔄 Procesando archivo \(index+1) de \(urls.count): \(url.lastPathComponent)")
                        // Solicitar acceso de seguridad para cada archivo
                        if url.startAccessingSecurityScopedResource() {
                            // Asegurarse de que se libere el acceso cuando terminemos
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            // Procesar el archivo en el hilo principal para mantener la coherencia
                            DispatchQueue.main.sync {
                                viewModel.processImportedFile(url: url)
                            }
                        } else {
                            print("❌ No se pudo acceder al archivo de manera segura: \(url.path)")
                        }
                    }
                    
                    // Desactivar el indicador de carga cuando se complete todo el proceso
                    DispatchQueue.main.async {
                        print("✅ Importación completada: \(urls.count) archivos procesados")
                        viewModel.isProcessingFiles = false
                        LoadingManager.shared.stopLoading()
                    }
                }
            case .failure(let error):
                print("❌ Error al importar archivos: \(error)")
                // Asegurarse de desactivar los indicadores de carga en caso de error
                DispatchQueue.main.async {
                    viewModel.isProcessingFiles = false
                    LoadingManager.shared.stopLoading()
                }
            }
        }
    }
    
    // Vista de esqueleto de carga
    private var skeletonView: some View {
        ZStack {
            // Esqueleto de contenido
            ScrollView {
                // Compensación para el header
                Color.clear.frame(height: viewModel.isHeaderCompact ? 40 : 185)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Esqueleto para "Continuar leyendo"
                    VStack(alignment: .leading) {
                        // Título de sección
                        SkeletonView()
                            .frame(width: 180, height: 22)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                        
                        // Fila de libros
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(0..<4, id: \.self) { _ in
                                    VStack(spacing: 8) {
                                        // Portada de libro
                                        SkeletonView()
                                            .frame(width: UIScreen.main.bounds.width / 2 - 30, height: 200)
                                            .cornerRadius(10)
                                        
                                        // Título
                                        SkeletonView()
                                            .frame(width: UIScreen.main.bounds.width / 2 - 60, height: 16)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.leading, 24)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    
                    // Esqueleto para "Colecciones"
                    VStack(alignment: .leading) {
                        // Título de sección
                        SkeletonView()
                            .frame(width: 150, height: 22)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                        
                        // Fila de colecciones
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonView()
                                        .frame(width: 300, height: 180)
                                        .cornerRadius(16)
                                }
                                .padding(.leading, 24)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    
                    // Esqueleto para "Todos los libros"
                    VStack(alignment: .leading) {
                        // Título de sección
                        SkeletonView()
                            .frame(width: 160, height: 22)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                        
                        // Grid de libros
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                            ForEach(0..<12, id: \.self) { _ in
                                VStack(spacing: 8) {
                                    // Portada de libro
                                    SkeletonView()
                                        .aspectRatio(2/3, contentMode: .fit)
                                        .cornerRadius(10)
                                    
                                    // Título
                                    SkeletonView()
                                        .frame(height: 16)
                                        .cornerRadius(4)
                                    
                                    // Autor
                                    SkeletonView()
                                        .frame(height: 14)
                                        .cornerRadius(4)
                                        .opacity(0.7)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                    
                    Spacer(minLength: 80)
                }
            }
            .opacity(0.6) // Reducir levemente la opacidad para que destaque el indicador circular
            
            // Indicador de carga circular moderno en el centro
            ModernLoadingIndicator()
        }
    }
    
    // SkeletonView moved to Views/Home/SkeletonView.swift
    
    // Vista del encabezado con Liquid Glass adaptativo al scroll
    
    // continueLeerSection moved to Views/Home/ContinueReadingSection.swift
    
    // Sección "Tus colecciones" modernizada con Liquid Glass
    // CollectionsSection moved to Views/Home/CollectionsSection.swift
    
    // Sección "Todos los libros"
    // AllBooksSection moved to Views/Home/AllBooksSection.swift
    
    // Botón para cambiar el layout de la cuadrícula con Liquid Glass
    private var gridLayoutButton: some View {
        Button(action: {
            // Guardamos la categoría actual antes de cambiar el layout
            let currentCategory = viewModel.selectedCategory
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                viewModel.gridLayout = (viewModel.gridLayout + 1) % 3
                viewModel.storedGridLayout = viewModel.gridLayout
                
                // Refrescar el encabezado para evitar problemas visuales
                viewModel.refreshHeader()
                
                // Nos aseguramos de mantener la categoría actual
                if viewModel.selectedCategory != currentCategory {
                    viewModel.updateSelectedCategory(currentCategory)
                }
            }
        }) {
            Group {
                switch viewModel.gridLayout {
                case 0:
                    Image(systemName: "square.grid.2x2")
                case 1:
                    Image(systemName: "list.bullet")
                case 2:
                    Image(systemName: "square.grid.3x3")
                default:
                    Image(systemName: "square.grid.2x2")
                }
            }
            .font(.title2)
            .foregroundColor(.primary)
            .padding(.trailing, 24)
        }
    }
    
    // Vista para resultados de búsqueda vacíos
    private var emptySearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No se encontraron resultados para \"\(viewModel.searchText)\"")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Intenta con otros términos de búsqueda")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    // Vista para biblioteca vacía - Diseño moderno
    private var emptyLibraryView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Ícono simple y elegante
            Image(systemName: "books.vertical")
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appTheme(),
                            Color.appTheme().opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 48)
            
            // Título principal
            Text("Tu biblioteca está vacía")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            
            // Descripción
            Text("Importa tus libros y cómics favoritos\npara comenzar a disfrutar de la lectura")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 50)
                .padding(.bottom, 40)
            
            // Botón moderno con efecto glass
            Button(action: {
                viewModel.isImporting = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Importar libros")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        // Gradiente base
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.appTheme(),
                                        Color.appTheme().opacity(0.85)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Reflejo glass
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.25), location: 0),
                                        .init(color: Color.white.opacity(0.1), location: 0.5),
                                        .init(color: Color.clear, location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .shadow(color: Color.appTheme().opacity(0.4), radius: 20, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // Función para formatear el tamaño de archivos
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct SearchBarView: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 10)
                    .font(.system(size: 16))

                TextField("Buscar libros o cómics...", text: $text)
                    .padding(.vertical, 10)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onChange(of: isFocused) { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isSearching = isFocused || !text.isEmpty
                        }
                    }
                    .onChange(of: text) { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isSearching = isFocused || !text.isEmpty
                        }
                    }

                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 10)
                            .font(.system(size: 16))
                    }
                }
            }
            .background(
                ZStack {
                    // Fondo con vibrancy Liquid Glass
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                    // Reflejo de vidrio sutil
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(isFocused ? 0.15 : 0.08),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isFocused ? Color.appTheme().opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
            .shadow(color: isFocused ? Color.appTheme().opacity(0.15) : Color.black.opacity(0.04), radius: isFocused ? 6 : 2, x: 0, y: isFocused ? 3 : 1)

            if isSearching && isFocused {
                Button("Cancelar") {
                    text = ""
                    isFocused = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isSearching = false
                    }
                }
                .padding(.leading, 8)
                .font(.system(size: 16))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(height: 44)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isFocused)
    }
}

// Helper view for category buttons con Liquid Glass
struct CategoryButton: View {
    let category: HomeViewModel.BookCategory
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        if isSelected {
                            // Botón seleccionado con efecto Liquid Glass
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.appTheme(),
                                            Color.appTheme().opacity(0.85)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            // Reflejo de vidrio
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.25),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        } else {
                            // Botón no seleccionado con vibrancy
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.12))
                        }
                    }
                    .shadow(color: isSelected ? Color.appTheme().opacity(0.3) : Color.black.opacity(0.04), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 2 : 1)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct ComicInfo: Codable {
    let title: String?
    let series: String?
    let number: String?
    let writer: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case series = "Series"
        case number = "Number"
        case writer = "Writer"
    }

    init(xmlData: Data) throws {
        let decoder = XMLDecoder()
        self = try decoder.decode(ComicInfo.self, from: xmlData)
    }
}

// Clase para manejar el parsing XML con XMLParser
class ComicInfoHandler: NSObject, XMLParserDelegate {
    var title: String?
    var series: String?
    var number: String?
    var writer: String?
    
    private var currentElement = ""
    private var currentValue = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Title":
            title = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case "Series":
            series = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case "Number":
            number = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case "Writer":
            writer = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            break
        }
    }
}

// Estilo de botón con efecto de escala al pulsar
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// Administrador de carga - Para gestionar de forma centralizada el estado de carga
class LoadingManager: ObservableObject {
    @Published var isLoading = false
    @Published var shouldShowFullscreenLoading = false
    
    static let shared = LoadingManager()
    
    private var loadingTimer: Timer?
    private var lockCount = 0
    
    func startLoading() {
        // Cancelar cualquier timer existente
        loadingTimer?.invalidate()
        
        DispatchQueue.main.async {
            // Incrementar el contador de bloqueo
            self.lockCount += 1
            self.isLoading = true
            
            // Solo mostrar el indicador de pantalla completa si la carga toma más de 300ms
            // Esto evita la experiencia de flash en cargas rápidas
            self.loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self, self.isLoading else { return }
                self.shouldShowFullscreenLoading = true
            }
        }
    }
    
    func stopLoading() {
        // Cancelar el timer
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        DispatchQueue.main.async {
            // Decrementar el contador de bloqueo
            self.lockCount = max(0, self.lockCount - 1)
            
            // Solo desactivar la carga si no hay más solicitudes pendientes
            if self.lockCount == 0 {
                self.isLoading = false
                self.shouldShowFullscreenLoading = false
            }
        }
    }
    
    // Método para forzar la detención de todas las cargas (usado para recuperación)
    func forceStopAllLoading() {
        // Cancelar el timer
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        DispatchQueue.main.async {
            // Reiniciar contador y estados
            self.lockCount = 0
            self.isLoading = false
            self.shouldShowFullscreenLoading = false
        }
    }
}

// Helper para esquinas redondeadas específicas
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Vista de tarjeta de colección con Liquid Glass
struct CollectionCardView: View {
    let collection: Collection
    let books: [CompleteBook]
    let viewModel: CollectionsViewModel
    let index: Int
    
    @State private var isVisible = false
    @State private var isHovered = false
    
    var body: some View {
        NavigationLink(destination: CollectionDetailView(collection: collection, viewModel: viewModel)) {
            VStack(alignment: .leading, spacing: 0) {
                // Contenedor de portadas con Liquid Glass moderno
                ZStack(alignment: .bottom) {
                    // Fondo con Material ultraThin
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Material.ultraThin)
                    
                    // Gradiente de color de la colección más sutil
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    collection.color.opacity(0.12),
                                    collection.color.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Reflejo de vidrio líquido superior
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.white.opacity(0.15), location: 0),
                                    .init(color: Color.clear, location: 0.4)
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    
                    // Portadas de libros
                    HomeCollectionView(books: books)
                        .frame(height: 165)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
                .frame(height: 185)
                .overlay(
                    // Borde sutil
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    collection.color.opacity(0.3),
                                    collection.color.opacity(0.08)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                
                // Información de la colección modernizada
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(collection.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Badge minimalista con cantidad
                        Text("\(books.count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(collection.color)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(Material.ultraThinMaterial)
                                    Capsule()
                                        .fill(collection.color.opacity(0.15))
                                    // Reflejo sutil
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.white.opacity(0.2), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(collection.color.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    // Fondo con Material para separación visual
                    ZStack {
                        RoundedCorner(
                            radius: 20,
                            corners: [.bottomLeft, .bottomRight]
                        )
                        .fill(Material.ultraThinMaterial)
                        
                        // Reflejo de vidrio muy sutil
                        RoundedCorner(
                            radius: 20,
                            corners: [.bottomLeft, .bottomRight]
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.white.opacity(0.08), location: 0),
                                    .init(color: Color.clear, location: 0.4)
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    }
                )
            }
            .frame(width: 330, height: 235)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            // Sombras Liquid Glass refinadas
            .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.06), radius: isHovered ? 20 : 12, x: 0, y: isHovered ? 10 : 6)
            .shadow(color: collection.color.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 14 : 8, x: 0, y: isHovered ? 7 : 4)
            // Efectos de animación spring suaves
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .rotation3DEffect(
                .degrees(isHovered ? 1 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                anchorZ: 0.0,
                perspective: 1.0
            )
            .brightness(isHovered ? 0.02 : 0)
            // Animaciones de aparición fluidas
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .blur(radius: isVisible ? 0 : 2)
            // Configuración de animaciones spring
            .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08 * Double(index)), value: isVisible)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovered)
            // Eventos de aparición
            .onAppear {
                // Animamos la aparición con un retraso basado en el índice
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + (0.06 * Double(index))) {
                    withAnimation {
                        isVisible = true
                    }
                }
            }
            .onHover { hovering in
                withAnimation {
                    isHovered = hovering
                }
            }
        }
    }
}

// ModernLoadingIndicator moved to Views/Home/ModernLoadingIndicator.swift
