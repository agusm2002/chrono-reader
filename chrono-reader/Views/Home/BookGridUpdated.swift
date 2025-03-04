//
//  BookGridViewUpdated.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import SwiftUI
import Combine

struct BookGridViewUpdated: View {
    @State private var books: [Book] = []
    @State private var searchQuery = ""
    @State private var isLoading = false
    @State private var cancellables = Set<AnyCancellable>()
    
    private let bookService = BookService()
    
    // Using fixed columns with proper spacing
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack {
            SearchBar(text: $searchQuery, onSearch: searchContent)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView("Cargando...")
                    .padding()
            } else if books.isEmpty {
                ContentUnavailableView(
                    "No se encontraron resultados",
                    systemImage: "magnifyingglass",
                    description: Text("Intenta con otra búsqueda o navega por tu biblioteca existente.")
                )
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(books) { book in
                            BookItemView(book: book)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .onAppear {
            // Cargar muestra inicial
            books = Book.samples
        }
    }
    
    private func searchContent() {
        guard !searchQuery.isEmpty else {
            books = Book.samples
            return
        }
        
        isLoading = true
        books = []
        
        // Buscar comics y libros en paralelo
        let comicsPublisher = bookService.searchComics(query: searchQuery)
        let booksPublisher = bookService.searchBooks(query: searchQuery)
        
        Publishers.Merge(comicsPublisher, booksPublisher)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    print("Error searching: \(error)")
                }
            }, receiveValue: { results in
                // Combinar y aplanar los resultados
                books = results.flatMap { $0 }
            })
            .store(in: &cancellables)
    }
}
