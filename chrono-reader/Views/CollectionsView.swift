// CollectionsView.swift

import SwiftUI

struct CollectionsView: View {
    @StateObject private var viewModel = CollectionsViewModel()
    @State private var isDragging = false
    @State private var draggedItemIndex: Int?
    @State private var dragCancellationTask: DispatchWorkItem?
    @AppStorage("collectionsHeaderCompact") private var storedIsHeaderCompact: Bool = false
    @State private var isHeaderCompact: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Content
                ScrollView {
                    // Spacer transparente para empujar el contenido debajo del header fijo
                    Color.clear.frame(height: isHeaderCompact ? 40 : (viewModel.isSearching ? 100 : 110))
                    
                    VStack(spacing: 0) {
                        // Sección de título y filtro (siempre visible)
                        HStack(alignment: .center) {
                            HeaderGradientText("Tus colecciones", fontSize: 20)
                            
                            Spacer()
                            
                            // Menú de ordenamiento
                            Menu {
                                ForEach(CollectionsViewModel.CollectionSortOption.allCases) { option in
                                    Button(action: {
                                        viewModel.selectedSortOption = option
                                        viewModel.storedSortOption = option.rawValue
                                    }) {
                                        HStack {
                                            Text(option.rawValue)
                                            if viewModel.selectedSortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(viewModel.selectedSortOption.rawValue)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        
                        if viewModel.collections.isEmpty {
                            emptyStateView
                                .padding(.top, 20)
                        } else {
                            collectionsListLayer
                                .padding(.top, 2)
                        }
                    }
                }
                
                // Header fijo
                VStack(spacing: 0) {
                    // Espacio para la barra de estado
                    Color.clear
                        .frame(height: 50)
                    
                    // Título de la biblioteca
                    HStack {
                        Text("Colecciones")
                            .font(.system(size: 32, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        
                        Spacer()
                        
                        // Botón para compactar/expandir el encabezado
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isHeaderCompact.toggle()
                                storedIsHeaderCompact = isHeaderCompact
                            }
                        }) {
                            Image(systemName: isHeaderCompact ? "chevron.down" : "chevron.up")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(.trailing, 8)
                                .padding(.top, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Botón de crear colección
                        Button(action: {
                            viewModel.showingCreateSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.appTheme())
                            .cornerRadius(8)
                            .padding(.trailing, 24)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, isHeaderCompact ? 6 : 8)
                    
                    // Barra de búsqueda y controles (visibles solo cuando el encabezado no está compacto)
                    if !isHeaderCompact {
                        // Solo barra de búsqueda
                        SearchBarView(text: $viewModel.searchText, isSearching: $viewModel.isSearching)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                            .padding(.bottom, 8)
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
            .sheet(isPresented: $viewModel.showingCreateSheet) {
                CreateCollectionView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadAvailableBooks()
                isHeaderCompact = storedIsHeaderCompact
                print("CollectionsView apareció, colecciones cargadas: \(viewModel.collections.count)")
            }
        }
        .accentColor(Color.appTheme())
    }
    
    private var collectionsListLayer: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.sortedCollections.enumerated()), id: \.element.id) { index, collection in
                CollectionRowView(
                    collection: collection,
                    viewModel: viewModel,
                    onDelete: {
                        viewModel.deleteCollection(collection)
                    }
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .opacity(isDragging && draggedItemIndex != index ? 0.7 : 1.0)
                .scaleEffect(isDragging && draggedItemIndex == index ? 1.03 : 1.0)
                .contentShape(Rectangle())
                .onDrag {
                    self.draggedItemIndex = index
                    self.isDragging = true
                    return NSItemProvider(object: "\(index)" as NSString)
                }
                .onDrop(of: [.text], delegate: CollectionDropDelegate(
                    item: collection,
                    currentIndex: index,
                    viewModel: viewModel,
                    isDragging: $isDragging,
                    draggedItemIndex: $draggedItemIndex
                ))
                .onChange(of: isDragging) { newValue in
                    if !newValue {
                        dragCancellationTask?.cancel()
                        let task = DispatchWorkItem {
                            draggedItemIndex = nil
                        }
                        dragCancellationTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                    }
                }
                // Eliminar animaciones durante el scroll
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .id("collectionsListContainer") // ID constante para preservar el estado
    }
    
    // Vista cuando no hay colecciones
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
                .padding()
            
            Text("No tienes colecciones todavía")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Crea colecciones para organizar tus libros y cómics favoritos")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            GradientButton("Crear colección") {
                viewModel.showingCreateSheet = true
            }
            .padding(.top, 16)
        }
        .padding()
    }
}

// Delegado para manejar el drop de colecciones
struct CollectionDropDelegate: DropDelegate {
    let item: Collection
    let currentIndex: Int
    let viewModel: CollectionsViewModel
    @Binding var isDragging: Bool
    @Binding var draggedItemIndex: Int?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedItemIndex = self.draggedItemIndex else { 
            return false 
        }
        
        if draggedItemIndex != currentIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.updateCollectionsOrder(from: draggedItemIndex, to: currentIndex)
            }
        }
        
        // Limpiar el estado
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isDragging = false
            }
            // Retrasamos la limpieza del índice para evitar saltos visuales
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.draggedItemIndex = nil
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // No hacemos cambios reales hasta que el drop se complete
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        // No hacemos nada aquí para mantener estado consistente
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return draggedItemIndex != nil && draggedItemIndex != currentIndex
    }
}

struct CollectionsView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionsView()
    }
} 