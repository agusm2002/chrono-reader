import SwiftUI

struct HomeView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedCategory: BookCategory = .all
    @State private var scrollOffset: CGFloat = 0
    
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
                // Transparent spacer to push content below the fixed header
                Color.clear.frame(height: 140)
                
                // Main content
                VStack(alignment: .leading, spacing: 24) {
                    // Continue reading section (if there are books in progress)
                    if !isSearching {
                        if !booksInProgress.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HeaderGradientText("Continuar leyendo", fontSize: 20)
                                    .padding(.horizontal, 24) // Increased padding
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(booksInProgress) { book in
                                            BookItemView(book: book)
                                                .frame(width: 150)
                                        }
                                    }
                                    .padding(.horizontal, 24) // Increased padding
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                    
                    // All books section
                    VStack(alignment: .leading, spacing: 16) {
                        if isSearching {
                            HeaderGradientText("Resultados de búsqueda", fontSize: 20)
                                .padding(.horizontal, 24)
                        } else {
                            HeaderGradientText("Todos los \(selectedCategory == .all ? "títulos" : selectedCategory.rawValue)", fontSize: 20)
                                .padding(.horizontal, 24)
                        }
                        
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
                            // Grid with all filtered books - Changed to the BookGridView component
                            BookGridView(books: filteredBooks)
                                .padding(.horizontal, 8) // Added extra padding to center grid items
                        }
                    }
                    
                    Spacer(minLength: 100) // Space for the tab bar
                }
            }
            .coordinateSpace(name: "scroll")
            
            // Fixed header elements
            VStack(spacing: 0) {
                // Top header (removed Chrono Reader text and rectangle)
                ZStack {
                    // Blurred header background
                    BlurredHeader()
                        .frame(height: 60)
                }
                .frame(height: 60)
                
                // Fixed category selector and Library title area
                VStack(alignment: .leading, spacing: 8) {
                    // Library title
                    Text("Biblioteca")
                        .font(.system(size: 25, weight: .bold))
                        .padding(.horizontal, 24) // Increased padding
                        .padding(.top, 8)
                    
                    // Search bar
                    SearchBarView(text: $searchText, isSearching: $isSearching)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    
                    // Category selector (hidden when searching)
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
                            .padding(.horizontal, 24) // Increased padding
                        }
                        .padding(.vertical, 8)
                    }
                }
                .background(Material.ultraThinMaterial) // Apply blur effect to this VStack
                .frame(height: isSearching ? 120 : 160)
            }
            .background(Color.clear) // Make sure the overall background is clear
            .ignoresSafeArea(edges: .top)
        }
    }
}

// Custom Search Bar Component
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
                    .padding(.vertical, 10)
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
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
