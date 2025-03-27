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

// Definir alias para evitar ambigüedades
typealias ZipArchive = ZIPFoundation.Archive
typealias RarArchive = Unrar.Archive

class HomeViewModel: ObservableObject {
    @Published var books: [CompleteBook] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var selectedCategory: BookCategory = .all
    @Published var isImporting: Bool = false
    @Published var isProcessingFiles: Bool = false // Nueva variable para controlar el estado de carga
    @Published var gridLayout: Int = 0 // 0: Default, 1: List, 2: Large
    @Published var isHeaderCompact: Bool = false // Variable para controlar si el encabezado está compacto
    @Published var collectionsViewModel = CollectionsViewModel() // Agregamos el ViewModel de colecciones
    
    // Toast notification state
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastStyle: ToastStyle = .success
    
    @AppStorage("books") private var storedBooksData: Data? // Persistencia con AppStorage
    
    enum BookCategory: String, CaseIterable, Identifiable {
        case all = "Todos"
        case books = "Libros"
        case comics = "Comics"
        case recent = "Recientes"
        case favorites = "Favoritos"

        var id: String { self.rawValue }
    }
    
    init() {
        loadBooks()
        
        // Asegurarse de que el CollectionsViewModel tenga los libros actualizados
        collectionsViewModel.loadAvailableBooks()
        
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
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    var filteredBooks: [CompleteBook] {
        var filtered = books

        if !searchText.isEmpty {
            filtered = filtered.filter { $0.book.title.lowercased().contains(searchText.lowercased()) ||
                                             $0.book.author.lowercased().contains(searchText.lowercased()) }
        }

        switch selectedCategory {
        case .all:
            return filtered
        case .books:
            return filtered.filter { $0.book.type == .epub || $0.book.type == .pdf }
        case .comics:
            return filtered.filter { $0.book.type == .cbr || $0.book.type == .cbz }
        case .recent:
            // Ordenar por fecha de última lectura (más reciente primero)
            return filtered.filter { $0.book.progress > 0 }.sorted { 
                guard let date1 = $0.book.lastReadDate else { return false }
                guard let date2 = $1.book.lastReadDate else { return true }
                return date1 > date2
            }
        case .favorites:
            return filtered.filter { $0.book.isFavorite }
        }
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
        
        // Limpiar el nombre del archivo eliminando el prefijo UUID
        let originalFileName = url.lastPathComponent
        let cleanFileName = originalFileName.replacingOccurrences(
            of: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}-",
            with: "",
            options: .regularExpression
        )
        
        // Eliminar la extensión del archivo
        let fileNameWithoutExtension = cleanFileName.replacingOccurrences(
            of: "\\.(cbz|cbr)$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        var title: String = fileNameWithoutExtension
        var series: String?
        var issueNumber: Int?
        
        // Usar el controlador adecuado según el tipo de archivo
        if type == .cbz {
            // Para archivos CBZ (ZIP)
            guard let archive = ZipArchive(url: url, accessMode: .read) else {
                print("Error: No se pudo abrir el archivo CBZ")
                return
            }
            
            // Intentar extraer ComicInfo.xml
            extractComicInfoFromZip(archive: archive, url: url, title: &title, author: &author, series: &series, issueNumber: &issueNumber)
            
            // Extraer la portada
            coverImage = extractCoverFromZip(archive: archive)
        } else if type == .cbr {
            // Para archivos CBR (RAR)
            do {
                print("Intentando abrir archivo RAR: \(url.path)")
                let archive = try RarArchive(path: url.path, password: nil)
                
                // Intentar extraer ComicInfo.xml
                extractComicInfoFromRar(archive: archive, url: url, title: &title, author: &author, series: &series, issueNumber: &issueNumber)
                
                // Extraer la portada
                coverImage = try extractCoverFromRar(archive: archive)
            } catch {
                print("Error al abrir archivo RAR: \(error)")
                return
            }
        } else {
            print("Tipo de archivo no soportado: \(type.rawValue)")
            return
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
        
        // Crear una nueva instancia con los metadatos actualizados
        newBook = CompleteBook(
            id: newBook.id,
            title: updatedBookCopy.title,
            author: updatedBookCopy.author,
            coverImage: updatedBookCopy.coverImage,
            type: updatedBookCopy.type,
            progress: updatedBookCopy.progress,
            localURL: url,
            cover: coverImage
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
        for entry in archive.sorted(by: { $0.path < $1.path }) {
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
                } catch {
                    print("Error al extraer la portada: \(error)")
                }
                break
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
            
            // Notificar cambios en los libros para que se actualicen las colecciones
            NotificationCenter.default.post(name: Notification.Name("BooksUpdated"), object: nil)
            
            // Forzar la actualización de la vista
            objectWillChange.send()
        } catch {
            print("Error al codificar los libros para guardar: \(error)")
        }
    }
    
    func loadBooks() {
        if let storedBooksData = storedBooksData {
            do {
                let decoded = try JSONDecoder().decode([CompleteBook].self, from: storedBooksData)
                books = decoded
                print("Libros cargados correctamente: \(books.count) libros")
                
                // Imprimir información de progreso para depuración
                for book in books where book.book.progress > 0 {
                    print("Libro cargado: \(book.book.title) - Progreso: \(book.book.progress * 100)%")
                }
                
                // Verificar y reparar las rutas de los archivos
                verifyAndRepairBookPaths()
            } catch {
                print("Error al decodificar los libros guardados: \(error)")
                loadSampleBooks()
            }
        } else {
            print("No se encontraron libros guardados")
            loadSampleBooks()
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
                    // Crear una nueva instancia con la portada regenerada
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
                            // Crear una nueva instancia con la portada regenerada
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
                        // Crear una nueva instancia con la portada generada
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
        
        if type == .cbz, let archive = ZipArchive(url: url, accessMode: .read) {
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
        } else if type == .cbr {
            do {
                print("Intentando abrir archivo RAR para extraer portada: \(url.path)")
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
                print("Error al extraer portada de archivo RAR: \(error)")
            }
        } else {
            print("No se pudo abrir el archivo")
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
        // Borrar todos los libros
        books.removeAll()
        
        // Borrar los datos guardados
        storedBooksData = nil
        
        // Cargar los libros de muestra
        loadSampleBooks()
        
        // Guardar los cambios
        saveBooks()
        
        print("Biblioteca reiniciada con libros de muestra")
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
                isFavorite: updatedBook.book.isFavorite
            )
            
            // Actualizar el libro en la colección
            books[index] = combinedBook
            
            // Guardar los cambios inmediatamente y notificar la actualización UI
            DispatchQueue.main.async {
                self.saveBooks()
                // Forzar actualización de la UI
                self.objectWillChange.send()
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

    // Función para actualizar el estado de favorito de un libro
    func toggleFavorite(book: CompleteBook) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            let updatedBook = book.withUpdatedFavorite(!book.book.isFavorite)
            books[index] = updatedBook
            saveBooks()
        }
    }

    private var cancellables = Set<AnyCancellable>()
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Contenido principal
            mainContent
            
            // Toast notification
            if viewModel.showToast {
                VStack {
                    Spacer()
                    
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                        
                        Text(viewModel.toastMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Para que aparezca por encima de la barra de navegación
                    .transition(.move(edge: .bottom))
                }
                .zIndex(999)
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: viewModel.showToast)
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
    }
    
    // Vista principal
    private var mainContent: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Content
                ScrollView {
                    // Spacer transparente para empujar el contenido debajo del header fijo
                    Color.clear.frame(height: viewModel.isHeaderCompact ? 70 : (viewModel.isSearching ? 130 : 185))

                    // Contenido principal
                    VStack(alignment: .leading, spacing: 24) {
                        // Sección de "Continuar leyendo"
                        continueLeerSection
                        
                        // Sección de "Tus colecciones"
                        coleccionesSection
                        
                        // Sección de "Todos los libros"
                        todosLibrosSection

                        Spacer(minLength: 100) // Aumentado de 90 a 100 para la barra de navegación más alta
                    }
                }
                .coordinateSpace(name: "scroll")
                .fileImporter(
                    isPresented: $viewModel.isImporting,
                    allowedContentTypes: [UTType.pdf, UTType.epub, UTType.init(filenameExtension: "cbr")!, UTType.init(filenameExtension: "cbz")!],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        // Activar el indicador de carga antes de comenzar a procesar
                        print("🔵 Comenzando importación de \(urls.count) archivos")
                        viewModel.isProcessingFiles = true
                        LoadingManager.shared.startLoading() // Activar la vista de carga
                        
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
                            
                            // Desactivar el indicador de carga cuando se completa todo el proceso
                            DispatchQueue.main.async {
                                print("✅ Importación completada: \(urls.count) archivos procesados")
                                viewModel.isProcessingFiles = false
                                LoadingManager.shared.stopLoading() // Desactivar la vista de carga
                            }
                        }
                    case .failure(let error):
                        print("❌ Error al importar archivos: \(error)")
                        viewModel.isProcessingFiles = false
                        LoadingManager.shared.stopLoading() // Desactivar la vista de carga en caso de error
                    }
                }

                // Header fijo
                headerView
            }
        }
    }
    
    // Sección "Continuar leyendo"
    private var continueLeerSection: some View {
        Group {
            if !viewModel.isSearching && !viewModel.booksInProgress.isEmpty && viewModel.selectedCategory == .all {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderGradientText("Continuar leyendo", fontSize: 20)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.booksInProgress) { book in
                                BookItemView(book: book, onDelete: {
                                    viewModel.deleteBook(book: book)
                                }, onToggleFavorite: {
                                    viewModel.toggleFavorite(book: book)
                                })
                                .frame(width: 150)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom)
            }
        }
    }
    
    // Sección "Tus colecciones"
    private var coleccionesSection: some View {
        Group {
            if !viewModel.isSearching && !viewModel.collectionsViewModel.collections.isEmpty && viewModel.selectedCategory == .all {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderGradientText("Tus colecciones", fontSize: 20)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(viewModel.collectionsViewModel.collections) { collection in
                                NavigationLink(destination: CollectionDetailView(collection: collection, viewModel: viewModel.collectionsViewModel)) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        StackedCoversView(books: viewModel.collectionsViewModel.booksInCollection(collection))
                                            .padding(.top, 12)
                                            .padding(.horizontal, 10)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(collection.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            let booksCount = viewModel.collectionsViewModel.booksInCollection(collection).count
                                            Text("\(booksCount) \(booksCount == 1 ? "libro" : "libros")")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.gray.opacity(0.1))
                                    }
                                    .frame(width: 220)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(collection.color.opacity(0.15))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom)
            }
        }
    }
    
    // Sección "Todos los libros"
    private var todosLibrosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header de la sección
            HStack {
                HeaderGradientText(viewModel.isSearching ? "Resultados de búsqueda" : "Todos los \(viewModel.selectedCategory == .all ? "títulos" : viewModel.selectedCategory.rawValue)", fontSize: 20)
                    .padding(.horizontal, 24)

                Spacer()

                // Botón para ajustar la vista de cuadrícula
                gridLayoutButton
            }

            // Contenido basado en el estado
            Group {
                if viewModel.filteredBooks.isEmpty && !viewModel.searchText.isEmpty {
                    emptySearchResultsView
                } else if viewModel.books.isEmpty {
                    emptyLibraryView
                } else {
                    // Vista de libros filtrados
                    BookGridUpdatedView(books: viewModel.filteredBooks, gridLayout: viewModel.gridLayout, onDelete: { book in
                        viewModel.deleteBook(book: book)
                    }, onToggleFavorite: { book in
                        viewModel.toggleFavorite(book: book)
                    })
                        .padding(.horizontal, 8)
                }
            }
        }
    }
    
    // Botón para cambiar el layout de la cuadrícula
    private var gridLayoutButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.gridLayout = (viewModel.gridLayout + 1) % 3
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
    
    // Vista para biblioteca vacía
    private var emptyLibraryView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 150, height: 150)
                
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                        .offset(y: -5)
                }
            }
            .padding(.bottom, 10)
            
            Text("Tu biblioteca está vacía")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Importa tus libros y cómics favoritos\npara comenzar a disfrutar de la lectura")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Mostrar el selector de archivos
                viewModel.isImporting = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                    Text("Importar libros")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 16)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Vista del encabezado
    private var headerView: some View {
        VStack(spacing: 0) {
            // Espacio para la barra de estado
            Color.clear
                .frame(height: 50)
            
            // Título de la biblioteca
            HStack {
                Text("Biblioteca")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer()
                
                // Botón para compactar/expandir el encabezado
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.isHeaderCompact.toggle()
                    }
                }) {
                    Image(systemName: viewModel.isHeaderCompact ? "chevron.down" : "chevron.up")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                }

                // Botón de importación
                Button(action: {
                    viewModel.isImporting = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                }
                
                // Botón para reiniciar la biblioteca
                Button(action: {
                    showLibraryOptions()
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, viewModel.isHeaderCompact ? 8 : 10) // Margen inferior reducido para mejor equilibrio

            // Barra de búsqueda y categorías (visibles solo cuando el encabezado no está compacto)
            if !viewModel.isHeaderCompact {
                // Barra de búsqueda
                SearchBarView(text: $viewModel.searchText, isSearching: $viewModel.isSearching)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Selector de categorías (oculto durante la búsqueda)
                if !viewModel.isSearching {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(HomeViewModel.BookCategory.allCases) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: viewModel.selectedCategory == category,
                                    action: { viewModel.selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .background(
            Material.ultraThinMaterial
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3))
                .offset(y: 1),
            alignment: .bottom
        )
        .ignoresSafeArea(edges: .top)
    }
    
    // Función para mostrar opciones de biblioteca
    private func showLibraryOptions() {
        let alert = UIAlertController(title: "Opciones de biblioteca", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Verificar y reparar archivos", style: .default) { _ in
            viewModel.verifyAndRepairBookPaths()
        })
        
        alert.addAction(UIAlertAction(title: "Reiniciar biblioteca", style: .destructive) { _ in
            // Mostrar alerta de confirmación para reiniciar
            let confirmAlert = UIAlertController(title: "Reiniciar biblioteca", message: "¿Estás seguro de que quieres borrar todos los libros y cargar solo los de muestra?", preferredStyle: .alert)
            
            confirmAlert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
            confirmAlert.addAction(UIAlertAction(title: "Reiniciar", style: .destructive) { _ in
                viewModel.resetToSampleBooks()
            })
            
            // Presentar la alerta de confirmación
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(confirmAlert, animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Presentar el menú de opciones
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popoverController = alert.popoverPresentationController {
                // Para iPad, necesitamos especificar el origen del popover
                popoverController.sourceView = rootViewController.view
                popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            rootViewController.present(alert, animated: true)
        }
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
                    .onChange(of: isFocused) { newValue in
                        withAnimation {
                            isSearching = newValue || !text.isEmpty
                        }
                    }
                    .onChange(of: text) { newValue in
                        withAnimation {
                            isSearching = isFocused || !newValue.isEmpty
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
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )

            if isSearching && isFocused {
                Button("Cancelar") {
                    text = ""
                    isFocused = false
                    withAnimation {
                        isSearching = false
                    }
                }
                .padding(.leading, 8)
                .font(.system(size: 16))
                .transition(.move(edge: .trailing))
            }
        }
        .frame(height: 44)
    }
}

// Helper view for category buttons
struct CategoryButton: View {
    let category: HomeViewModel.BookCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue.opacity(0.9) : Color.gray.opacity(0.1))
                        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 2, x: 0, y: 1)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
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
    
    static let shared = LoadingManager()
    
    func startLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    func stopLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}
