// CollectionsView.swift

import SwiftUI

struct CollectionsView: View {
    @StateObject private var viewModel = CollectionsViewModel()
    
    // Bindings externos para búsqueda desde el tab bar
    @Binding var externalSearchText: String
    @Binding var externalIsSearching: Bool
    
    init(externalSearchText: Binding<String> = .constant(""), externalIsSearching: Binding<Bool> = .constant(false)) {
        self._externalSearchText = externalSearchText
        self._externalIsSearching = externalIsSearching
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Espacio adicional para alinear con el botón
                    Color.clear.frame(height: 8)
                    
                    // Sección de título y filtro
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
                    
                    Spacer(minLength: 120)
                }
            }
            .navigationTitle("Colecciones")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showingCreateSheet = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.appTheme())
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateSheet) {
                CreateCollectionView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadAvailableBooks()
                print("CollectionsView apareció, colecciones cargadas: \(viewModel.collections.count)")
            }
            .onChange(of: externalSearchText) { newValue in
                viewModel.searchText = newValue
            }
            .onChange(of: externalIsSearching) { newValue in
                viewModel.isSearching = newValue
            }
            .onChange(of: viewModel.searchText) { newValue in
                externalSearchText = newValue
            }
            .onChange(of: viewModel.isSearching) { newValue in
                externalIsSearching = newValue
            }
        }
        .accentColor(Color.appTheme())
    }
    
    private var collectionsListLayer: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.sortedCollections) { collection in
                CollectionRowView(
                    collection: collection,
                    viewModel: viewModel,
                    onDelete: {
                        viewModel.deleteCollection(collection)
                    }
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                // Eliminar animaciones durante el scroll
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .id("collectionsListContainer") // ID constante para preservar el estado
    }
    
    // Vista cuando no hay colecciones - Diseño moderno
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Ícono simple y elegante
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appTheme(),
                            Color.appTheme().opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 48)
            
            // Título principal
            Text("No tienes colecciones todavía")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            
            // Descripción
            Text("Crea colecciones para organizar\ntus libros y cómics favoritos")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 50)
                .padding(.bottom, 40)
            
            // Botón moderno con efecto glass
            Button(action: {
                viewModel.showingCreateSheet = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Crear colección")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        // Gradiente base
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.appTheme(),
                                        Color.appTheme().opacity(0.85)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Reflejo glass
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.25), location: 0),
                                        .init(color: Color.white.opacity(0.1), location: 0.5),
                                        .init(color: Color.clear, location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .shadow(color: Color.appTheme().opacity(0.4), radius: 20, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CollectionsView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionsView(externalSearchText: .constant(""), externalIsSearching: .constant(false))
    }
} 