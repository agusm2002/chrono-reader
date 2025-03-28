// CreateCollectionView.swift

import SwiftUI

struct CreateCollectionView: View {
    @ObservedObject var viewModel: CollectionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
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
                        .background(
                            viewModel.newCollectionName.isEmpty || viewModel.selectedBooks.isEmpty ?
                            Color.gray : viewModel.newCollectionColor
                        )
                        .cornerRadius(10)
                }
                .disabled(viewModel.newCollectionName.isEmpty || viewModel.selectedBooks.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 16)
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
        .accentColor(Color.appTheme())
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
        VStack(spacing: 24) {
            // Contador de selección
            HStack {
                Text("\(viewModel.selectedBooks.count) \(viewModel.selectedBooks.count == 1 ? "libro seleccionado" : "libros seleccionados")")
                    .font(.headline)
                    .foregroundColor(viewModel.newCollectionColor)
                
                Spacer()
                
                if !viewModel.selectedBooks.isEmpty {
                    Button("Deseleccionar todos") {
                        viewModel.selectedBooks.removeAll()
                    }
                    .foregroundColor(viewModel.newCollectionColor)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Grid de libros
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 24) {
                    ForEach(viewModel.availableBooks) { book in
                        BookSelectionItem(
                            book: book,
                            isSelected: viewModel.selectedBooks.contains(book.id),
                            selectionColor: viewModel.newCollectionColor,
                            onToggle: {
                                if viewModel.selectedBooks.contains(book.id) {
                                    viewModel.selectedBooks.remove(book.id)
                                } else {
                                    viewModel.selectedBooks.insert(book.id)
                                }
                            }
                        )
                        .frame(height: 180) // Asegurar altura consistente para cada item
                        .padding(.horizontal, 2) // Pequeño padding adicional para separar los elementos
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 24) // Aumentado de 16 a 24 para compensar la eliminación del espaciador
                .padding(.bottom, 16)
            }
        }
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
            ZStack(alignment: .topTrailing) {
                // Portada del libro con área de toque restringida
                Group {
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
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(2/3, contentMode: .fill)
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
            
            Text(book.book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
                .foregroundColor(isSelected ? selectionColor : .primary)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }
}

struct CreateCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CollectionsViewModel()
        return CreateCollectionView(viewModel: viewModel)
    }
} 