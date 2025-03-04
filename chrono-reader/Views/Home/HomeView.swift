//
//  HomeView.swift
//  chrono-reader
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedCategory: BookCategory = .all
    @State private var isImporting: Bool = false
    @State private var newBookURL: URL?
    @State private var books: [Book] = Book.samples  // Estado local para los libros

    enum BookCategory: String, CaseIterable, Identifiable {
        case all = "Todos"
        case books = "Libros"
        case comics = "Comics"
        case recent = "Recientes"

        var id: String { self.rawValue }
    }

    var filteredBooks: [Book] {
        var filtered = books

        if !searchText.isEmpty {
            filtered = filtered.filter { $0.title.lowercased().contains(searchText.lowercased()) ||
                                             $0.author.lowercased().contains(searchText.lowercased()) }
        }

        switch selectedCategory {
        case .all:
            return filtered
        case .books:
            return filtered.filter { $0.type == .epub || $0.type == .pdf }
        case .comics:
            return filtered.filter { $0.type == .cbr || $0.type == .cbz }
        case .recent:
            return filtered.filter { $0.progress > 0 }.sorted(by: { $0.progress > $1.progress })
        }
    }

    var booksInProgress: [Book] {
        return filteredBooks.filter { $0.progress > 0 }.sorted(by: { $0.progress > $1.progress })
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
        // Aquí se implementa la lógica para extraer metadatos del archivo
        // y crear una nueva instancia de Book.
        
        // Para simplificar, crearemos un nuevo Book con información básica
        let newBook = Book(
            title: url.lastPathComponent,  // Usamos el nombre del archivo como título
            author: "Desconocido",         // Autor desconocido por defecto
            coverImage: "",                // Dejamos la portada vacía por ahora
            type: getBookType(for: url),   // Determinamos el tipo de archivo
            progress: 0.0                  // Progreso inicial en 0
        )

        // Agregamos el nuevo libro a la lista
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
