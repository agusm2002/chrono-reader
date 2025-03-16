// CollectionsViewModel.swift

import Foundation
import SwiftUI
import Combine

class CollectionsViewModel: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var showingCreateSheet = false
    @Published var selectedBooks: Set<UUID> = []
    @Published var newCollectionName = ""
    @Published var newCollectionColor: Color = .blue
    
    // Referencia a los libros disponibles
    @Published var availableBooks: [CompleteBook] = []
    
    // Persistencia con AppStorage
    @AppStorage("collections") private var storedCollectionsData: Data?
    
    // Colores predefinidos para elegir
    let availableColors: [Color] = [
        .blue, .red, .green, .orange, .purple, .pink, .yellow, .teal
    ]
    
    init() {
        loadCollections()
        
        // Observar cambios en los libros disponibles
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BooksUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadAvailableBooks()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadAvailableBooks() {
        // Cargar los libros desde HomeViewModel
        if let storedBooksData = UserDefaults.standard.data(forKey: "books") {
            do {
                let decoded = try JSONDecoder().decode([CompleteBook].self, from: storedBooksData)
                self.availableBooks = decoded
                print("Libros cargados para colecciones: \(availableBooks.count)")
            } catch {
                print("Error al decodificar los libros para colecciones: \(error)")
                self.availableBooks = []
            }
        } else {
            print("No se encontraron libros guardados para colecciones")
            self.availableBooks = []
        }
    }
    
    // Obtener los libros de una colección específica
    func booksInCollection(_ collection: Collection) -> [CompleteBook] {
        return collection.books.compactMap { bookId in
            availableBooks.first { $0.id == bookId }
        }
    }
    
    // Función para actualizar el orden de los libros en una colección
    func updateBooksOrder(in collection: Collection, books: [CompleteBook]) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index].books = books.map { $0.id }
            saveCollections()
            print("Orden de libros actualizado en colección: \(collection.name)")
        }
    }
    
    // Crear una nueva colección
    func createCollection() {
        guard !newCollectionName.isEmpty && !selectedBooks.isEmpty else { return }
        
        let newCollection = Collection(
            name: newCollectionName,
            books: Array(selectedBooks),
            color: newCollectionColor
        )
        
        collections.append(newCollection)
        saveCollections()
        
        // Resetear los valores
        newCollectionName = ""
        selectedBooks = []
        showingCreateSheet = false
    }
    
    // Eliminar una colección
    func deleteCollection(_ collection: Collection) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections.remove(at: index)
            saveCollections()
        }
    }
    
    // Añadir libros a una colección existente
    func addBooksToCollection(_ collection: Collection, books: [UUID]) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            var updatedCollection = collection
            updatedCollection.books.append(contentsOf: books)
            // Eliminar duplicados
            updatedCollection.books = Array(Set(updatedCollection.books))
            collections[index] = updatedCollection
            saveCollections()
        }
    }
    
    // Eliminar un libro de una colección
    func removeBookFromCollection(_ collection: Collection, bookID: UUID) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            var updatedCollection = collection
            updatedCollection.books.removeAll(where: { $0 == bookID })
            collections[index] = updatedCollection
            saveCollections()
        }
    }
    
    // Guardar colecciones
    func saveCollections() {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(collections)
            storedCollectionsData = encoded
            print("Colecciones guardadas correctamente: \(collections.count)")
        } catch {
            print("Error al codificar las colecciones: \(error)")
        }
    }
    
    // Cargar colecciones
    func loadCollections() {
        if let storedCollectionsData = storedCollectionsData {
            do {
                let decoded = try JSONDecoder().decode([Collection].self, from: storedCollectionsData)
                collections = decoded
                print("Colecciones cargadas correctamente: \(collections.count)")
            } catch {
                print("Error al decodificar las colecciones: \(error)")
                collections = []
            }
        } else {
            print("No se encontraron colecciones guardadas")
            collections = []
        }
        
        // Cargar los libros disponibles
        loadAvailableBooks()
    }
    
    // Función para renombrar una colección
    func renameCollection(_ collection: Collection, newName: String) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index].name = newName
            saveCollections()
            print("Colección renombrada a: \(newName)")
        }
    }
    
    // Función para actualizar el orden de las colecciones
    func updateCollectionsOrder(from fromIndex: Int, to toIndex: Int) {
        let collection = collections.remove(at: fromIndex)
        collections.insert(collection, at: toIndex)
        saveCollections()
        print("Orden de colecciones actualizado")
    }
} 