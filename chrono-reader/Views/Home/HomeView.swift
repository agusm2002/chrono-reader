import SwiftUI

struct HomeView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedCategory: BookCategory = .all

    let books = Book.samples

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

            // Header fijo
            VStack(spacing: 0) {
                // Top header (fondo con blur)
                BlurredHeader()
                    .frame(height: 50) // Reducimos el tamaño del BlurredHeader

                // Contenedor del título y la barra de búsqueda
                VStack(alignment: .leading, spacing: 8) {
                    // Título de la biblioteca
                    Text("Biblioteca")
                        .font(.system(size: 25, weight: .bold))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Barra de búsqueda
                    SearchBarView(text: $searchText, isSearching: $isSearching)
                        .padding(.horizontal, 16) // Reducimos el padding horizontal
                        .padding(.bottom, 4) // Reducimos el padding bottom

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
                        .padding(.bottom, 8) // Agregamos un padding inferior adicional
                    }
                }
                .background(Material.ultraThinMaterial) // Aplicar blur
            }
            .background(Color.clear) // Asegurarse de que el fondo sea transparente
            .ignoresSafeArea(edges: .top) // Ignorar el área segura superior para que llegue al tope
        }
    }
}

// Componente de barra de búsqueda personalizada
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
                    .padding(.vertical, 8) // Reducimos el padding vertical
                    .font(.system(size: 14)) // Reducimos el tamaño de la fuente
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
            .cornerRadius(8) // Reducimos el radio del corner
            .overlay(
                RoundedRectangle(cornerRadius: 8) // Reducimos el radio del corner
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5) // Reducimos el grosor de la línea
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
        .frame(height: 36) // Establecemos una altura fija más pequeña
    }
}

// Vista auxiliar para los botones de categoría
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
