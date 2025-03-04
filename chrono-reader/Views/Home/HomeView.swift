//
//  HomeView.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import SwiftUI

struct HomeView: View {
    // State variables
    @State private var searchText = ""
    @State private var selectedCategory: BookCategory = .all
    @State private var scrollOffset: CGFloat = 0
    
    // Sample data
    let books = Book.samples
    
    // Enum for category selection
    enum BookCategory: String, CaseIterable, Identifiable {
        case all = "Todos"
        case books = "Libros"
        case comics = "Comics"
        case recent = "Recientes"
        
        var id: String { self.rawValue }
    }
    
    var filteredBooks: [Book] {
        var filtered = books
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.title.lowercased().contains(searchText.lowercased()) ||
                                         $0.author.lowercased().contains(searchText.lowercased()) }
        }
        
        // Filter by category
        switch selectedCategory {
        case .all:
            return filtered
        case .books:
            return filtered.filter { $0.type == .epub || $0.type == .pdf }
        case .comics:
            return filtered.filter { $0.type == .cbr || $0.type == .cbz }
        case .recent:
            // This would normally come from a database of recently opened books
            return filtered.filter { $0.progress > 0 }.sorted(by: { $0.progress > $1.progress })
        }
    }
    
    // Books in progress
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
                    
                    // All books section
                    VStack(alignment: .leading, spacing: 16) {
                        HeaderGradientText("Todos los \(selectedCategory == .all ? "títulos" : selectedCategory.rawValue)", fontSize: 20)
                            .padding(.horizontal, 24) // Increased padding
                        
                        // Grid with all filtered books - Changed to the BookGridView component
                        BookGridView(books: filteredBooks)
                            .padding(.horizontal, 8) // Added extra padding to center grid items
                    }
                    
                    Spacer(minLength: 100) // Space for the tab bar
                }
            }
            .coordinateSpace(name: "scroll")
            .searchable(text: $searchText, prompt: "Buscar libros o cómics")
            
            // Fixed header elements
            VStack(spacing: 0) {
                // Top header with app title
                ZStack {
                    // Blurred header background
                    BlurredHeader()
                        .frame(height: 60)
                    
                    // App title and icon with rounded rectangle background
                    HStack(spacing: 12) {
                        // Container for app icon and name with gray background
                        HStack(spacing: 8) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            
                            Text("Chrono Reader")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                        )
                    }
                }
                .frame(height: 60)
                
                // Fixed category selector and Library title area
                VStack(alignment: .leading, spacing: 8) {
                    // Library title
                    Text("Biblioteca")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 24) // Increased padding
                        .padding(.top, 8)
                    
                    // Category selector
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
                .background(Color.white)
                .frame(height: 80)
            }
            .background(Color.white)
            .ignoresSafeArea(edges: .top)
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
