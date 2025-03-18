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
        
        // Observar actualizaciones de progreso de libros individuales
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BookProgressUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let updatedBook = notification.userInfo?["book"] as? CompleteBook {
                print("Colecciones: Recibida notificación de progreso para: \(updatedBook.book.title) - \(updatedBook.book.progress * 100)%")
                self.updateBookProgress(updatedBook)
            } else {
                print("Colecciones: Error al obtener libro actualizado de la notificación")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadAvailableBooks() {
        // Cargar los libros desde AppStorage para asegurar que tengamos los datos más recientes
        if let storedBooksData = UserDefaults.standard.data(forKey: "books") {
            do {
                let decoded = try JSONDecoder().decode([CompleteBook].self, from: storedBooksData)
                self.availableBooks = decoded
                print("Libros cargados para colecciones: \(availableBooks.count)")
                
                // Revisar y limpiar colecciones para eliminar referencias a libros que ya no existen
                cleanUpCollections()
            } catch {
                print("Error al decodificar los libros para colecciones: \(error)")
                self.availableBooks = []
            }
        } else {
            print("No se encontraron libros guardados para colecciones")
            self.availableBooks = []
        }
    }
    
    // Función para limpiar las colecciones y eliminar referencias a libros que ya no existen
    func cleanUpCollections() {
        var needsUpdate = false
        
        for (index, collection) in collections.enumerated() {
            let existingBookIds = Set(availableBooks.map { $0.id })
            let collectionBookIds = Set(collection.books)
            
            // Buscar libros que están en la colección pero no en la biblioteca
            let missingBooks = collectionBookIds.subtracting(existingBookIds)
            
            if !missingBooks.isEmpty {
                print("Limpiando colección \(collection.name): eliminando \(missingBooks.count) libros que ya no existen")
                var updatedCollection = collection
                updatedCollection.books.removeAll(where: { missingBooks.contains($0) })
                collections[index] = updatedCollection
                needsUpdate = true
            }
        }
        
        if needsUpdate {
            saveCollections()
            print("Colecciones actualizadas después de limpieza")
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
        guard !books.isEmpty, 
              let index = collections.firstIndex(where: { $0.id == collection.id }) else { 
            print("No se pudo actualizar el orden: colección no encontrada o libros vacíos")
            return 
        }
        
        print("Actualizando orden de libros en colección: \(collection.name)")
        print("Libros recibidos para reordenar: \(books.count)")
        
        // Extraer los IDs
        let bookIds = books.map { $0.id }
        
        // Verificar longitudes para asegurar que no se pierdan libros
        let currentBookIds = collections[index].books
        if bookIds.count != currentBookIds.count {
            print("Error: El recuento de libros no coincide - actual: \(currentBookIds.count), nuevo: \(bookIds.count)")
            
            // Imprimir detalles para depuración
            print("IDs actuales: \(currentBookIds)")
            print("IDs nuevos: \(bookIds)")
            return
        }
        
        // Verificar que todos los libros actuales están incluidos en la nueva lista
        let currentIdSet = Set(currentBookIds)
        let newIdSet = Set(bookIds)
        
        if currentIdSet != newIdSet {
            print("Error: Los conjuntos de libros no son idénticos")
            
            // Encontrar las diferencias para depuración
            let missingIds = currentIdSet.subtracting(newIdSet)
            let extraIds = newIdSet.subtracting(currentIdSet)
            
            if !missingIds.isEmpty {
                print("IDs que faltan en la nueva lista: \(missingIds)")
            }
            
            if !extraIds.isEmpty {
                print("IDs extra en la nueva lista: \(extraIds)")
            }
            
            return
        }
        
        // Todo parece estar en orden, actualizar y guardar
        collections[index].books = bookIds
        
        // Imprimir el nuevo orden para depuración
        print("Nuevo orden de libros:")
        for (i, id) in bookIds.enumerated() {
            if let book = availableBooks.first(where: { $0.id == id }) {
                print("[\(i)] - \(book.book.title)")
            } else {
                print("[\(i)] - ID: \(id) (no encontrado)")
            }
        }
        
        saveCollections()
        print("Orden de libros actualizado con éxito en colección: \(collection.name)")
        
        // Notificar a las vistas para que se actualicen
        objectWillChange.send()
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
        guard fromIndex >= 0, fromIndex < collections.count,
              toIndex >= 0, toIndex < collections.count,
              fromIndex != toIndex else { 
            return 
        }
        
        let collection = collections.remove(at: fromIndex)
        collections.insert(collection, at: toIndex)
        saveCollections()
        print("Orden de colecciones actualizado: de \(fromIndex) a \(toIndex)")
    }
    
    // Actualizar el progreso de un libro en la lista de libros disponibles
    func updateBookProgress(_ updatedBook: CompleteBook) {
        print("Colecciones: Actualizando libro: \(updatedBook.book.title)")
        
        // Paso 1: Actualizar el libro en nuestra lista local de libros disponibles
        if let index = availableBooks.firstIndex(where: { $0.id == updatedBook.id }) {
            print("Colecciones: Libro encontrado en posición \(index), actualizando progreso")
            availableBooks[index] = updatedBook
            
            // Notificar a nuestras vistas que deben actualizarse
            objectWillChange.send()
        } else {
            print("Colecciones: Libro no encontrado en lista local, cargando todos los libros")
            // Si no encontramos el libro, recargamos todos los libros disponibles
            loadAvailableBooks()
        }
        
        // Paso 2: Acceder directamente a UserDefaults para actualizar el libro en la biblioteca principal
        if let storedBooksData = UserDefaults.standard.data(forKey: "books"),
           var storedBooks = try? JSONDecoder().decode([CompleteBook].self, from: storedBooksData) {
            
            if let bookIndex = storedBooks.firstIndex(where: { $0.id == updatedBook.id }) {
                print("Colecciones: Actualizando libro directamente en UserDefaults")
                storedBooks[bookIndex] = updatedBook
                
                if let encodedBooks = try? JSONEncoder().encode(storedBooks) {
                    UserDefaults.standard.set(encodedBooks, forKey: "books")
                    UserDefaults.standard.synchronize()
                    
                    // Notificar al HomeViewModel que debe actualizar su UI
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("BooksUpdated"),
                            object: nil
                        )
                    }
                }
            }
        }
    }
} 