//
//  HomeView.swift
//

import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import XMLCoder

struct HomeView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedCategory: BookCategory = .all
    @State private var isImporting: Bool = false
    @State private var newBookURL: URL?
    @State private var books: [CompleteBook] = []  // Estado local para los libros

    enum BookCategory: String, CaseIterable, Identifiable {
        case all = "Todos"
        case books = "Libros"
        case comics = "Comics"
        case recent = "Recientes"

        var id: String { self.rawValue }
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
            return filtered.filter { $0.book.progress > 0 }.sorted(by: { $0.book.progress > $1.book.progress })
        }
    }

    var booksInProgress: [CompleteBook] {
        return filteredBooks.filter { $0.book.progress > 0 }.sorted(by: { $0.book.progress > $1.book.progress })
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Content
            ScrollView {
                // Spacer transparente para empujar el contenido debajo del header fijo
                Color.clear.frame(height: isSearching ? 110 : 150) // Ajuste dinámico del height

                // Contenido principal
                VStack(alignment: .leading, spacing: 24) {
                    // Sección de "Continuar leyendo" (si hay libros en progreso)
                    if !isSearching {
                        if !booksInProgress.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HeaderGradientText("Continuar leyendo", fontSize: 20)
                                    .padding(.horizontal, 24)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(booksInProgress) { book in
                                            BookItemView(book: book)
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
                        HeaderGradientText(isSearching ? "Resultados de búsqueda" : "Todos los \(selectedCategory == .all ? "títulos" : selectedCategory.rawValue)", fontSize: 20)
                            .padding(.horizontal, 24)

                        if filteredBooks.isEmpty && !searchText.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)

                                Text("No se encontraron resultados para \"\(searchText)\"")
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
                            BookGridView(books: filteredBooks)
                                .padding(.horizontal, 8)
                        }
                    }

                    Spacer(minLength: 100) // Espacio para la barra de navegación
                }
            }
            .coordinateSpace(name: "scroll")
            .onChange(of: newBookURL) { url in
                if let url = url {
                    // Procesar el nuevo archivo seleccionado y agregarlo a la lista de libros
                    processImportedFile(url: url)
                    newBookURL = nil // Resetear la URL después de procesar
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType.pdf, UTType.epub, UTType.init(filenameExtension: "cbr")!, UTType.init(filenameExtension: "cbz")!],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    // Tomar la primera URL seleccionada
                    if let url = urls.first {
                        newBookURL = url
                    }
                case .failure(let error):
                    print(error)
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
                            isImporting = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(.trailing, 24)
                                .padding(.top, 8)
                        }
                    }

                    // Barra de búsqueda
                    SearchBarView(text: $searchText, isSearching: $isSearching)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                    // Selector de categorías (oculto durante la búsqueda)
                    if !isSearching {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(BookCategory.allCases) { category in
                                    CategoryButton(
                                        category: category,
                                        isSelected: selectedCategory == category,
                                        action: { selectedCategory = category }
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

    private func processImportedFile(url: URL) {
        // 1. Determinar el tipo de archivo
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "cbz", "cbr":
            processComicBookFile(url: url, type: (fileExtension == "cbz" ? .cbz : .cbr))
        default:
            // Para otros tipos de archivo, crearemos un nuevo Book con información básica
            let newBook = CompleteBook(title: url.lastPathComponent, author: "Desconocido", coverImage: "", type: getBookType(for: url), progress: 0.0, localURL: url)
            books.append(newBook)
        }
    }
    
    private func processComicBookFile(url: URL, type: BookType) {
        guard let archive = Archive(url: url, accessMode: .read) else {
            print("Error: No se pudo abrir el archivo CBZ/CBR")
            return
        }

        var coverImage: UIImage?
        var author: String = "Desconocido"
        var title: String = url.lastPathComponent // Default title

        // Buscar ComicInfo.xml y extraer metadatos
        for entry in archive {
            if entry.path.lowercased() == "comicinfo.xml" {
                do {
                    var data = Data()
                    try archive.extract(entry) { data.append($0) }
                    
                    if let comicInfo = try? ComicInfo(xmlData: data) {
                        author = comicInfo.writer ?? author
                        title = comicInfo.title ?? title
                    }
                } catch {
                    print("Error al extraer ComicInfo.xml: \(error)")
                }
                break
            }
        }

        // Buscar la primera imagen (JPG o PNG) para usar como portada
        for entry in archive {
            if entry.path.lowercased().hasSuffix(".jpg") || entry.path.lowercased().hasSuffix(".png") {
                do {
                    var data = Data()
                    try archive.extract(entry) { data.append($0) }
                    coverImage = UIImage(data: data)
                    
                    // Found cover, break the loop
                    break
                } catch {
                    print("Error al extraer la imagen de portada: \(error)")
                }
            }
        }
        
        let newBook = CompleteBook(title: title, author: author, coverImage: "", type: type, progress: 0.0, localURL: url, cover: coverImage)
        
        books.append(newBook)
    }

    private func getBookType(for url: URL) -> BookType {
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
    let category: HomeView.BookCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.3, blue: 0.9),
                                    Color(red: 0.6, green: 0.3, blue: 0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// Helper struct to decode ComicInfo.xml
struct ComicInfo: Decodable {
    let title: String?
    let series: String?
    let number: String?
    let volume: String?
    let writer: String?
    let penciller: String?
    let inker: String?
    let colorist: String?
    let letterer: String?
    let editor: String?
    let publisher: String?
    let genre: String?
    let web: String?
    let summary: String?
    let notes: String?
    let year: String?
    let month: String?
    let day: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case series = "Series"
        case number = "Number"
        case volume = "Volume"
        case writer = "Writer"
        case penciller = "Penciller"
        case inker = "Inker"
        case colorist = "Colorist"
        case letterer = "Letterer"
        case editor = "Editor"
        case publisher = "Publisher"
        case genre = "Genre"
        case web = "Web"
        case summary = "Summary"
        case notes = "Notes"
        case year = "Year"
        case month = "Month"
        case day = "Day"
    }
    
    init(xmlData: Data) throws {
        let decoder = XMLDecoder()
        self = try decoder.decode(ComicInfo.self, from: xmlData)
    }
}
