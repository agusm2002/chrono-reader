// CollectionsViewModel.swift

import Foundation
import SwiftUI
import Combine

class CollectionsViewModel: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var showingCreateSheet = false
    @Published var selectedBooks: Set<UUID> = []
    @Published var newCollectionName = ""
    @Published var newCollectionColor: Color = Color.appTheme()
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    
    // Referencia a los libros disponibles
    @Published var availableBooks: [CompleteBook] = []
    
    // Persistencia con AppStorage
    @AppStorage("collections") private var storedCollectionsData: Data?
    @AppStorage("collectionsSortOption") var storedSortOption: String = CollectionSortOption.dateCreatedDesc.rawValue
    
    // Colecciones filtradas y ordenadas para evitar recálculos continuos
    @Published private(set) var sortedCollections: [Collection] = []
    
    // Separamos sort option para evitar actualizaciones innecesarias
    private var _selectedSortOption: CollectionSortOption = .dateCreatedDesc
    var selectedSortOption: CollectionSortOption {
        get { _selectedSortOption }
        set {
            if _selectedSortOption != newValue {
                _selectedSortOption = newValue
                updateSortedCollections()
            }
        }
    }
    
    // Colores predefinidos para elegir
    let availableColors: [Color] = [
        .blue, .red, .green, .orange, .purple, .pink, .yellow, .teal
    ]
    
    enum CollectionSortOption: String, CaseIterable, Identifiable {
        case intelligent = "Auto"
        case alphabeticalAsc = "A-Z"
        case alphabeticalDesc = "Z-A"
        case dateCreatedDesc = "Fecha de creación (nuevo)"
        case dateCreatedAsc = "Fecha de creación (antiguo)"
        case progressDesc = "Progreso (alto)"
        case progressAsc = "Progreso (bajo)"
        case bookCountDesc = "Más libros"
        case bookCountAsc = "Menos libros"
        
        var id: String { self.rawValue }
    }
    
    // Cancellables para gestionar suscripciones
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCollections()
        loadAvailableBooks() // Cargar libros disponibles al inicio
        _selectedSortOption = CollectionSortOption(rawValue: storedSortOption) ?? .dateCreatedDesc
        
        // Inicializar las colecciones ordenadas
        updateSortedCollections()
        
        // Crear combinación de publicadores para actualizar cuando cambian criterios
        Publishers.CombineLatest($collections, $searchText)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateSortedCollections()
            }
            .store(in: &cancellables)
        
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
                print("Colecciones: Recibida notificación de progreso para: \(updatedBook.displayTitle) - \(updatedBook.book.progress * 100)%")
                
                // En lugar de actualizar directamente, esperamos a que el HomeViewModel actualice el libro
                // y luego recargaremos los libros disponibles cuando se notifique BooksUpdated
                // Esto evita inconsistencias entre el estado de los libros en HomeViewModel y CollectionsViewModel
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
                
                // Verificar la integridad de las colecciones
                verifyCollectionsIntegrity()
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
        
        // Obtener todos los IDs de libros disponibles
        let existingBookIds = Set(availableBooks.map { $0.id })
        
        // Buscar también en UserDefaults por seguridad
        var additionalIds = Set<UUID>()
        if let storedBooksData = UserDefaults.standard.data(forKey: "books") {
            do {
                let decoded = try JSONDecoder().decode([CompleteBook].self, from: storedBooksData)
                additionalIds = Set(decoded.map { $0.id })
            } catch {
                print("Error al decodificar libros desde UserDefaults: \(error)")
            }
        }
        
        // Combinar todos los IDs conocidos
        let allKnownBookIds = existingBookIds.union(additionalIds)
        
        for (index, collection) in collections.enumerated() {
            let collectionBookIds = Set(collection.books)
            
            // Buscar libros que están en la colección pero no en la biblioteca
            let missingBooks = collectionBookIds.subtracting(allKnownBookIds)
            
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
    
    // Función para verificar la integridad de las colecciones
    func verifyCollectionsIntegrity() {
        print("=== VERIFICACIÓN DE INTEGRIDAD DE COLECCIONES ===")
        print("Total de libros disponibles: \(availableBooks.count)")
        
        for collection in collections {
            print("\n- Colección: \(collection.name)")
            print("  IDs de libros en la colección: \(collection.books.count)")
            
            // Verificar si hay libros en la colección que no existen en availableBooks
            let existingBookIds = Set(availableBooks.map { $0.id })
            let collectionBookIds = Set(collection.books)
            let missingBooks = collectionBookIds.subtracting(existingBookIds)
            
            if !missingBooks.isEmpty {
                print("  ⚠️ ALERTA: \(missingBooks.count) libros no encontrados en la biblioteca")
                for id in missingBooks {
                    print("    - ID que falta: \(id)")
                }
            } else {
                print("  ✓ Todos los IDs de libros están presentes en availableBooks")
            }
            
            // Verificar los libros que realmente están en la colección
            let booksInCollection = collection.books.compactMap { bookId in
                availableBooks.first { $0.id == bookId }
            }
            
            print("  Libros que se pueden cargar: \(booksInCollection.count) de \(collection.books.count)")
            
            if booksInCollection.count != collection.books.count {
                print("  ⚠️ ALERTA: No todos los libros pueden ser cargados")
            }
            
            // Verificar si hay duplicados en los IDs de libros
            let duplicateIds = collection.books.filter { id in
                collection.books.filter { $0 == id }.count > 1
            }
            
            if !duplicateIds.isEmpty {
                let uniqueDuplicates = Set(duplicateIds)
                print("  ⚠️ ALERTA: \(uniqueDuplicates.count) IDs duplicados encontrados")
            } else {
                print("  ✓ No hay IDs duplicados")
            }
        }
        
        print("=== FIN DE VERIFICACIÓN DE INTEGRIDAD ===")
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
                print("[\(i)] - \(book.displayTitle)")
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
        let newCollection = Collection(
            name: newCollectionName,
            books: Array(selectedBooks),
            color: newCollectionColor
        )
        
        collections.append(newCollection)
        saveCollections()
        
        // Resetear el estado
        newCollectionName = ""
        selectedBooks.removeAll()
        showingCreateSheet = false
    }
    
    func resetCreateCollectionState() {
        newCollectionName = ""
        selectedBooks.removeAll()
        searchText = ""
        isSearching = false
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
    
    // Actualizar un libro en todas las colecciones que lo contengan
    func updateBookInCollections(_ updatedBook: CompleteBook) {
        print("Actualizando libro en colecciones: \(updatedBook.displayTitle)")
        
        // Primero actualizamos el libro en la lista de libros disponibles
        if let index = availableBooks.firstIndex(where: { $0.id == updatedBook.id }) {
            availableBooks[index] = updatedBook
            print("Libro actualizado en availableBooks")
        } else {
            // Si el libro no existe en availableBooks, lo añadimos
            availableBooks.append(updatedBook)
            print("Libro añadido a availableBooks")
        }
        
        // No es necesario modificar las colecciones ya que estas sólo almacenan los IDs de los libros,
        // y el ID del libro no ha cambiado
        
        // Notificar cambios para actualizar la UI
        objectWillChange.send()
    }
    
    // Actualizar el progreso de un libro específico
    func updateBookProgress(_ updatedBook: CompleteBook) {
        // Actualizar el libro en availableBooks
        updateBookInCollections(updatedBook)
    }
    
    // Método para actualizar las colecciones ordenadas
    private func updateSortedCollections() {
        // Primero filtramos las colecciones basadas en el texto de búsqueda
        let filteredCollections = searchText.isEmpty 
            ? collections 
            : collections.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        
        // Aplicamos el ordenamiento seleccionado
        var sorted: [Collection]
        
        switch _selectedSortOption {
        case .alphabeticalAsc:
            sorted = filteredCollections.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .alphabeticalDesc:
            sorted = filteredCollections.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .dateCreatedDesc:
            sorted = filteredCollections.sorted { $0.dateCreated > $1.dateCreated }
        case .dateCreatedAsc:
            sorted = filteredCollections.sorted { $0.dateCreated < $1.dateCreated }
        case .progressDesc:
            sorted = filteredCollections.sorted { getCollectionProgress($0) > getCollectionProgress($1) }
        case .progressAsc:
            sorted = filteredCollections.sorted { getCollectionProgress($0) < getCollectionProgress($1) }
        case .bookCountDesc:
            sorted = filteredCollections.sorted { $0.books.count > $1.books.count }
        case .bookCountAsc:
            sorted = filteredCollections.sorted { $0.books.count < $1.books.count }
        case .intelligent:
            sorted = filteredCollections.sorted { collection1, collection2 in
                // 1. Priorizar colecciones con más libros
                if collection1.books.count != collection2.books.count {
                    return collection1.books.count > collection2.books.count
                }
                
                // 2. Priorizar por progreso promedio
                let progress1 = getCollectionProgress(collection1)
                let progress2 = getCollectionProgress(collection2)
                if progress1 != progress2 {
                    return progress1 > progress2
                }
                
                // 3. Priorizar por fecha de creación (más recientes)
                if collection1.dateCreated != collection2.dateCreated {
                    return collection1.dateCreated > collection2.dateCreated
                }
                
                // 4. Si no hay otros criterios, ordenar alfabéticamente
                return collection1.name.localizedCompare(collection2.name) == .orderedAscending
            }
        }
        
        // Actualizamos la lista ordenada
        self.sortedCollections = sorted
    }
    
    // Método para borrar completamente todas las colecciones
    func clearAllCollections() {
        collections.removeAll()
        sortedCollections.removeAll()
        
        // Asegurar que se borren todos los datos almacenados
        storedCollectionsData = nil
        
        // Forzar actualización de UserDefaults
        UserDefaults.standard.removeObject(forKey: "collections")
        UserDefaults.standard.synchronize()
        
        // Notificar cambios
        objectWillChange.send()
        print("Todas las colecciones han sido eliminadas completamente")
    }
    
    private func getCollectionProgress(_ collection: Collection) -> Double {
        let books = availableBooks.filter { collection.books.contains($0.id) }
        if books.isEmpty { return 0 }
        let totalProgress = books.reduce(0.0) { $0 + $1.book.progress }
        return totalProgress / Double(books.count)
    }
} 