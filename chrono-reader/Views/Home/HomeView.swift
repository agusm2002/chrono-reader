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

// Definir alias para evitar ambigüedades
typealias ZipArchive = ZIPFoundation.Archive
typealias RarArchive = Unrar.Archive

class HomeViewModel: ObservableObject {
    @Published var books: [CompleteBook] = []
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var selectedCategory: BookCategory = .all
    @Published var isImporting: Bool = false
    @Published var newBookURL: URL?
    @Published var gridLayout: Int = 0 // 0: Default, 1: List, 2: Large
    
    @AppStorage("books") private var storedBooksData: Data? // Persistencia con AppStorage
    
    enum BookCategory: String, CaseIterable, Identifiable {
        case all = "Todos"
        case books = "Libros"
        case comics = "Comics"
        case recent = "Recientes"

        var id: String { self.rawValue }
    }
    
    init() {
        loadBooks()
        
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
            default:
                // Para otros tipos de archivo, crearemos un nuevo Book con información básica
                let newBook = CompleteBook(title: url.lastPathComponent, author: "Desconocido", coverImage: "", type: getBookType(for: url), progress: 0.0, localURL: destinationURL)
                addBook(newBook)
            }
            
            // Guardar los cambios inmediatamente
            saveBooks()
        } catch {
            print("Error al copiar el archivo: \(error)")
            
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
                default:
                    let newBook = CompleteBook(title: url.lastPathComponent, author: "Desconocido", coverImage: "", type: getBookType(for: url), progress: 0.0, localURL: destinationURL)
                    addBook(newBook)
                }
                
                // Guardar los cambios inmediatamente
                saveBooks()
            } catch {
                print("Error en el método alternativo: \(error)")
            }
        }
    }
    
    // Función para extraer metadatos de un cómic
    func processComicBookFile(url: URL, type: BookType) {
        print("Procesando cómic: \(url.lastPathComponent)")
        print("Tipo de archivo: \(type.rawValue)")
        
        var coverImage: UIImage?
        var author: String = "Desconocido"
        var title: String = url.deletingPathExtension().lastPathComponent
        var series: String?
        var issueNumber: Int?
        
        // Extraer solo el nombre del archivo sin el prefijo UUID y sin la extensión
        let originalFileName = url.lastPathComponent
        
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
        // Si no hay libros guardados, cargar los libros de muestra
        books = Book.samples.map { book in
            CompleteBook(
                title: book.title, 
                author: book.author, 
                coverImage: book.coverImage, 
                type: book.type, 
                progress: book.progress,
                lastReadDate: book.lastReadDate
            )
        }
        print("Cargados \(books.count) libros de muestra")
    }
    
    // Función para verificar y reparar las rutas de los archivos
    func verifyAndRepairBookPaths() {
        let fileManager = FileManager.default
        var needsSaving = false
        
        print("Verificando y reparando rutas de archivos...")
        
        for (index, book) in books.enumerated() {
            // Verificar si la portada existe
            if let coverPath = book.metadata.coverPath {
                if !fileManager.fileExists(atPath: coverPath) {
                    print("Portada no encontrada para \(book.book.title): \(coverPath)")
                    
                    // Intentar regenerar la portada si es un cómic
                    if (book.book.type == .cbz || book.book.type == .cbr), 
                       let url = book.metadata.localURL, 
                       fileManager.fileExists(atPath: url.path) {
                        print("Intentando regenerar portada desde: \(url.path)")
                        if let coverImage = extractCoverFromComic(url: url, type: book.book.type) {
                            // Crear una nueva instancia con la portada regenerada
                            let updatedBook = CompleteBook(
                                id: book.id,
                                title: book.book.title,
                                author: book.book.author,
                                coverImage: book.book.coverImage,
                                type: book.book.type,
                                progress: book.book.progress,
                                localURL: book.metadata.localURL,
                                cover: coverImage
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
                if (book.book.type == .cbz || book.book.type == .cbr), 
                   let url = book.metadata.localURL, 
                   fileManager.fileExists(atPath: url.path) {
                    print("Intentando generar portada desde: \(url.path)")
                    if let coverImage = extractCoverFromComic(url: url, type: book.book.type) {
                        // Crear una nueva instancia con la portada generada
                        let updatedBook = CompleteBook(
                            id: book.id,
                            title: book.book.title,
                            author: book.book.author,
                            coverImage: book.book.coverImage,
                            type: book.book.type,
                            progress: book.book.progress,
                            localURL: book.metadata.localURL,
                            cover: coverImage
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
    
    // Función para extraer la portada de un cómic
    func extractCoverFromComic(url: URL, type: BookType) -> UIImage? {
        guard type == .cbz || type == .cbr else { return nil }
        
        print("Extrayendo portada de: \(url.path)")
        
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
            
            // Crear una nueva instancia que combine el progreso actualizado con la portada existente
            let combinedBook: CompleteBook
            
            // Si el libro actualizado tiene una portada, usarla
            if let updatedCover = updatedBook.getCoverImage() {
                print("Usando portada del libro actualizado")
                combinedBook = updatedBook
            } else if let existingCover = existingBook.getCoverImage() {
                // Si no, usar la portada existente
                print("Usando portada del libro existente")
                combinedBook = CompleteBook(
                    id: updatedBook.id,
                    title: updatedBook.book.title,
                    author: updatedBook.book.author,
                    coverImage: updatedBook.book.coverImage,
                    type: updatedBook.book.type,
                    progress: updatedBook.book.progress,
                    localURL: updatedBook.metadata.localURL,
                    cover: existingCover,
                    lastReadDate: updatedBook.book.lastReadDate // Preservar la fecha de última lectura
                )
            } else {
                print("No se encontró ninguna portada")
                combinedBook = updatedBook
            }
            
            // Actualizar el libro en la colección
            books[index] = combinedBook
            
            // Guardar los cambios inmediatamente
            DispatchQueue.main.async {
                self.saveBooks()
                print("Progreso actualizado y guardado para \(combinedBook.book.title): \(combinedBook.book.progress * 100)%")
            }
        } else {
            print("No se encontró el libro con ID: \(updatedBook.id) - Añadiendo a la colección")
            // Si el libro no existe en la colección, añadirlo
            books.append(updatedBook)
            
            // Guardar los cambios inmediatamente
            DispatchQueue.main.async {
                self.saveBooks()
                print("Nuevo libro añadido y guardado: \(updatedBook.book.title)")
            }
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        ZStack(alignment: .top) {
            // Content
            ScrollView {
                // Spacer transparente para empujar el contenido debajo del header fijo
                Color.clear.frame(height: viewModel.isSearching ? 110 : 150) // Ajuste dinámico del height

                // Contenido principal
                VStack(alignment: .leading, spacing: 24) {
                    // Sección de "Continuar leyendo" (si hay libros en progreso)
                    if !viewModel.isSearching {
                        if !viewModel.booksInProgress.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HeaderGradientText("Continuar leyendo", fontSize: 20)
                                    .padding(.horizontal, 24)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(viewModel.booksInProgress) { book in
                                            BookItemView(book: book, onDelete: {
                                                viewModel.deleteBook(book: book)
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

                    // Sección de "Todos los libros"
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            HeaderGradientText(viewModel.isSearching ? "Resultados de búsqueda" : "Todos los \(viewModel.selectedCategory == .all ? "títulos" : viewModel.selectedCategory.rawValue)", fontSize: 20)
                                .padding(.horizontal, 24)

                            Spacer()

                            // Grid layout adjustment button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.gridLayout = (viewModel.gridLayout + 1) % 3
                                }
                            }) {
                                switch viewModel.gridLayout {
                                case 0:
                                    Image(systemName: "square.grid.2x2")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                        .padding(.trailing, 24)
                                case 1:
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                        .padding(.trailing, 24)
                                case 2:
                                    Image(systemName: "square.grid.3x3")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                        .padding(.trailing, 24)
                                default:
                                    Image(systemName: "square.grid.2x2")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                        .padding(.trailing, 24)
                                }
                            }
                        }

                        if viewModel.filteredBooks.isEmpty && !viewModel.searchText.isEmpty {
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
                        } else {
                            // Grid con todos los libros filtrados
                            BookGridUpdatedView(books: viewModel.filteredBooks, gridLayout: viewModel.gridLayout, onDelete: { book in
                                viewModel.deleteBook(book: book)
                            })
                                .padding(.horizontal, 8)
                        }
                    }

                    Spacer(minLength: 100) // Espacio para la barra de navegación
                }
            }
            .coordinateSpace(name: "scroll")
            .onChange(of: viewModel.newBookURL) { url in
                if let url = url {
                    // Procesar el nuevo archivo seleccionado y agregarlo a la lista de libros
                    viewModel.processImportedFile(url: url)
                    viewModel.newBookURL = nil // Resetear la URL después de procesar
                }
            }
            .fileImporter(
                isPresented: $viewModel.isImporting,
                allowedContentTypes: [UTType.pdf, UTType.epub, UTType.init(filenameExtension: "cbr")!, UTType.init(filenameExtension: "cbz")!],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    // Tomar la primera URL seleccionada
                    if let url = urls.first {
                        // Solicitar acceso de seguridad para el archivo
                        if url.startAccessingSecurityScopedResource() {
                            // Asegurarse de que se libere el acceso cuando terminemos
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            // Procesar el archivo
                            viewModel.newBookURL = url
                        } else {
                            print("No se pudo acceder al archivo de manera segura: \(url.path)")
                        }
                    }
                case .failure(let error):
                    print("Error al importar archivo: \(error)")
                }
            }

            // Header fijo
            VStack(spacing: 0) {
                // Top header (fondo con blur)
                BlurredHeader()
                    .frame(height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    // Título de la biblioteca
                    HStack {
                        Text("Biblioteca")
                            .font(.system(size: 25, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        Spacer()

                        // Botón de importación
                        Button(action: {
                            viewModel.isImporting = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(.trailing, 24)
                                .padding(.top, 8)
                        }
                    }

                    // Barra de búsqueda
                    SearchBarView(text: $viewModel.searchText, isSearching: $viewModel.isSearching)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                    // Selector de categorías (oculto durante la búsqueda)
                    if !viewModel.isSearching {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(HomeViewModel.BookCategory.allCases) { category in
                                    CategoryButton(
                                        category: category,
                                        isSelected: viewModel.selectedCategory == category,
                                        action: { viewModel.selectedCategory = category }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 8)
                    }
                }
                .background(Material.ultraThinMaterial)
            }
            .background(Color.clear)
            .ignoresSafeArea(edges: .top)
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
                    .padding(.leading, 8)

                TextField("Buscar libros o cómics...", text: $text)
                    .padding(.vertical, 8)
                    .font(.system(size: 14))
                    .focused($isFocused)
                    .onChange(of: isFocused) { newValue in
                        isSearching = newValue || !text.isEmpty
                    }
                    .onChange(of: text) { newValue in
                        isSearching = isFocused || !newValue.isEmpty
                    }

                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )

            if isSearching && isFocused {
                Button("Cancelar") {
                    text = ""
                    isFocused = false
                    isSearching = false
                }
                .padding(.leading, 8)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isSearching)
            }
        }
        .frame(height: 36)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
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

