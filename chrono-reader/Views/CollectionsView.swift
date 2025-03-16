// CollectionsView.swift

import SwiftUI

struct CollectionsView: View {
    @StateObject private var viewModel = CollectionsViewModel()
    @State private var isDragging = false
    @State private var draggedItemIndex: Int?
    
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
                                    .onDrag {
                                        draggedItemIndex = index
                                        isDragging = true
                                        return NSItemProvider(object: "\(index)" as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: CollectionDropDelegate(
                                        item: collection,
                                        currentIndex: index,
                                        viewModel: viewModel,
                                        isDragging: $isDragging,
                                        draggedItemIndex: $draggedItemIndex
                                    ))
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
        guard let fromIndex = draggedItemIndex else { return false }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.updateCollectionsOrder(from: fromIndex, to: currentIndex)
            isDragging = false
            draggedItemIndex = nil
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let fromIndex = draggedItemIndex,
              fromIndex != currentIndex else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.updateCollectionsOrder(from: fromIndex, to: currentIndex)
            draggedItemIndex = currentIndex
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        // No reseteamos isDragging aquí para evitar parpadeos durante el arrastre
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return draggedItemIndex != nil
    }
}

struct CollectionsView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionsView()
    }
} 