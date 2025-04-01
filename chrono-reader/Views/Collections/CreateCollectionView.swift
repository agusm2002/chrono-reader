// CreateCollectionView.swift

import SwiftUI

struct CreateCollectionView: View {
    @ObservedObject var viewModel: CollectionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @AppStorage("collectionSortOption") private var storedSortOption: String = SortOption.intelligent.rawValue
    @State private var selectedSortOption: SortOption = .intelligent
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tabs para seleccionar entre configuración y selección de libros
                HStack(spacing: 0) {
                    TabButton(title: "Configuración", isSelected: selectedTab == 0) {
                        withAnimation {
                            selectedTab = 0
                        }
                    }
                    
                    TabButton(title: "Seleccionar libros", isSelected: selectedTab == 1) {
                        withAnimation {
                            selectedTab = 1
                            // Cerrar el teclado al cambiar a la pestaña de selección
                            isNameFieldFocused = false
                        }
                    }
                }
                .padding(.top, 8)
                
                // Contenido según la pestaña seleccionada
                TabView(selection: $selectedTab) {
                    // Pestaña de configuración
                    configurationTab
                        .tag(0)
                    
                    // Pestaña de selección de libros
                    booksSelectionTab
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Botón de crear
                Button(action: {
                    viewModel.createCollection()
                    dismiss()
                }) {
                    Text("Crear colección")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appTheme())
                        .cornerRadius(12)
                }
                .padding()
                .disabled(viewModel.newCollectionName.isEmpty)
            }
            .navigationTitle("Nueva colección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Inicializar el ordenamiento desde el almacenamiento
            selectedSortOption = SortOption(rawValue: storedSortOption) ?? .intelligent
        }
    }
    
    // Pestaña de configuración
    private var configurationTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Nombre de la colección
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre de la colección")
                        .font(.headline)
                    
                    TextField("Ej: Favoritos, Para leer después...", text: $viewModel.newCollectionName)
                        .focused($isNameFieldFocused)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Selección de color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(viewModel.availableColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .padding(2)
                                        .opacity(viewModel.newCollectionColor == color ? 1 : 0)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .onTapGesture {
                                    viewModel.newCollectionColor = color
                                }
                        }
                    }
                }
                
                // Vista previa
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vista previa")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        // Portadas escalonadas (placeholder)
                        ZStack {
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewModel.newCollectionColor.opacity(0.8 - Double(index) * 0.2))
                                    .frame(width: 60, height: 90)
                                    .rotationEffect(.degrees(Double(index * 5) - 5))
                                    .offset(x: CGFloat(index * 8) - 8, y: 0)
                                    .zIndex(Double(3 - index))
                            }
                        }
                        .frame(width: 80, height: 90)
                        
                        // Información de la colección
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.newCollectionName.isEmpty ? "Mi colección" : viewModel.newCollectionName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(viewModel.selectedBooks.count) \(viewModel.selectedBooks.count == 1 ? "libro" : "libros")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        ZStack {
                            // Gradiente sobre el fondo
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    viewModel.newCollectionColor.opacity(0.1),
                                    Color(.systemBackground).opacity(0.9)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    )
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                // Botón para ir a seleccionar libros
                Button(action: {
                    withAnimation {
                        selectedTab = 1
                    }
                }) {
                    Text("Seleccionar libros")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.newCollectionColor)
                        .cornerRadius(10)
                }
                .disabled(viewModel.newCollectionName.isEmpty)
                .opacity(viewModel.newCollectionName.isEmpty ? 0.6 : 1)
            }
            .padding()
        }
    }
    
    // Pestaña de selección de libros
    private var booksSelectionTab: some View {
        VStack(spacing: 0) {
            // Header con búsqueda
            HStack {
                // Barra de búsqueda
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                    
                    TextField("Buscar libros...", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 8)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 10)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // Lista de libros
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(sortedBooks) { book in
                        BookSelectionItem(
                            book: book,
                            isSelected: viewModel.selectedBooks.contains(book.id),
                            selectionColor: viewModel.newCollectionColor
                        ) {
                            if viewModel.selectedBooks.contains(book.id) {
                                viewModel.selectedBooks.remove(book.id)
                            } else {
                                viewModel.selectedBooks.insert(book.id)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var sortedBooks: [CompleteBook] {
        let filtered = viewModel.availableBooks.filter { book in
            viewModel.searchText.isEmpty || 
            book.displayTitle.localizedCaseInsensitiveContains(viewModel.searchText)
        }
        
        // Ordenamiento inteligente por defecto
        return filtered.sorted { book1, book2 in
            let title1 = book1.displayTitle.lowercased()
            let title2 = book2.displayTitle.lowercased()
            
            // Extract series name and number if present
            let series1 = extractSeriesInfo(from: title1)
            let series2 = extractSeriesInfo(from: title2)
            
            if series1.name == series2.name {
                // If they're from the same series, sort by number
                return series1.number < series2.number
            } else {
                // If they're from different series, sort alphabetically
                return title1.localizedCompare(title2) == .orderedAscending
            }
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
}

// Botón de pestaña
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                Rectangle()
                    .fill(isSelected ? Color.appTheme() : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// Item de selección de libro
struct BookSelectionItem: View {
    let book: CompleteBook
    let isSelected: Bool
    let selectionColor: Color
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                // Portada con sus overlays
                ZStack(alignment: .topTrailing) {
                    // Base: portada
                    if let coverPath = book.metadata.coverPath,
                       let coverImage = UIImage(contentsOfFile: coverPath) {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        ZStack {
                            Color(.systemGray5)
                            Image(systemName: "book.closed")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Indicador de selección
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(selectionColor)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(6)
                    }
                }
                
                // Capa: gradiente para mejorar legibilidad
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
                
                // Barra de progreso y etiquetas
                if book.book.progress > 0 {
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
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Fondo de la barra
                                Rectangle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(height: 3)
                                
                                // Progreso
                                Rectangle()
                                    .fill(selectionColor)
                                    .frame(width: geometry.size.width * CGFloat(book.book.progress), height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(2/3, contentMode: .fit)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? selectionColor : Color.clear, lineWidth: 3)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                onToggle()
            }
            
            Text(book.displayTitle)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
                .foregroundColor(isSelected ? selectionColor : .primary)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
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
}

struct CreateCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CollectionsViewModel()
        return CreateCollectionView(viewModel: viewModel)
    }
} 