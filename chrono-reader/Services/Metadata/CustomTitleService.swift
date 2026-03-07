import Foundation

class CustomTitleService {
    static let shared = CustomTitleService()
    
    private let userDefaults = UserDefaults.standard
    private let customTitlesKey = "com.chronoreader.customtitles"
    
    private init() {}
    
    // Guardar el título personalizado
    func saveCustomTitle(bookId: UUID, title: String) {
        var allCustomTitles = getAllCustomTitles()
        
        // Actualizar o añadir el nuevo título
        allCustomTitles[bookId.uuidString] = title
        
        // Guardar en UserDefaults
        if let encoded = try? JSONEncoder().encode(allCustomTitles) {
            userDefaults.set(encoded, forKey: customTitlesKey)
            userDefaults.synchronize()
        }
    }
    
    // Obtener el título personalizado para un libro específico
    func getCustomTitle(for bookId: UUID) -> String? {
        return getAllCustomTitles()[bookId.uuidString]
    }
    
    // Eliminar el título personalizado para un libro específico
    func removeCustomTitle(for bookId: UUID) {
        var allCustomTitles = getAllCustomTitles()
        allCustomTitles.removeValue(forKey: bookId.uuidString)
        
        // Guardar en UserDefaults
        if let encoded = try? JSONEncoder().encode(allCustomTitles) {
            userDefaults.set(encoded, forKey: customTitlesKey)
            userDefaults.synchronize()
        }
    }
    
    // Obtener todos los títulos personalizados
    func getAllCustomTitles() -> [String: String] {
        guard let data = userDefaults.data(forKey: customTitlesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
