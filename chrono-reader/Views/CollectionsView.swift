// CollectionsView.swift

import SwiftUI

struct CollectionsView: View {
    @StateObject private var viewModel = CollectionsViewModel()
    
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
                                ForEach(viewModel.collections) { collection in
                                    CollectionRowView(
                                        collection: collection,
                                        books: viewModel.booksInCollection(collection),
                                        onDelete: {
                                            viewModel.deleteCollection(collection)
                                        }
                                    )
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

struct CollectionsView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionsView()
    }
} 