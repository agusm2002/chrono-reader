// CollectionsView.swift

import SwiftUI

struct CollectionsView: View {
    @StateObject private var viewModel = CollectionsViewModel()
    @State private var isDragging = false
    @State private var draggedItemIndex: Int?
    @State private var dragCancellationTask: DispatchWorkItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Contenido principal
                VStack(spacing: 0) {
                    if viewModel.collections.isEmpty {
                        // Vista cuando no hay colecciones
                        emptyStateView
                    } else {
                        // Lista de colecciones
                        ScrollView {
                            LazyVStack(spacing: 30) {
                                ForEach(Array(viewModel.collections.enumerated()), id: \.element.id) { index, collection in
                                    CollectionRowView(
                                        collection: collection,
                                        viewModel: viewModel,
                                        onDelete: {
                                            viewModel.deleteCollection(collection)
                                        }
                                    )
                                    .opacity(isDragging && draggedItemIndex != index ? 0.7 : 1.0)
                                    .scaleEffect(isDragging && draggedItemIndex == index ? 1.03 : 1.0)
                                    .zIndex(isDragging && draggedItemIndex == index ? 1 : 0)
                                    .shadow(color: isDragging && draggedItemIndex == index ? Color.black.opacity(0.2) : Color.clear, 
                                            radius: 5, x: 0, y: 3)
                                    .contentShape(Rectangle())
                                    .onDrag {
                                        self.draggedItemIndex = index
                                        self.isDragging = true
                                        // Usamos un formato simple para el identificador
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
                                        // Si se detiene el arrastre, programamos una tarea para limpiar el estado
                                        if !newValue {
                                            dragCancellationTask?.cancel()
                                            let task = DispatchWorkItem {
                                                draggedItemIndex = nil
                                            }
                                            dragCancellationTask = task
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Botón flotante para crear nueva colección
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.showingCreateSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Circle().fill(Color.blue))
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 65)
                        .disabled(isDragging)
                    }
                }
            }
            .navigationTitle("Colecciones")
            .sheet(isPresented: $viewModel.showingCreateSheet) {
                CreateCollectionView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadAvailableBooks()
            }
        }
    }
    
    // Vista cuando no hay colecciones
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
                .padding()
            
            Text("No tienes colecciones")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Crea colecciones para organizar tus libros y cómics favoritos")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                viewModel.showingCreateSheet = true
            }) {
                Text("Crear colección")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
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