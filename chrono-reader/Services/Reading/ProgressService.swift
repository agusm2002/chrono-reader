import Foundation

// Servicio para gestionar el progreso de lectura
class ProgressService {
    static let shared = ProgressService()
    
    private let userDefaults = UserDefaults.standard
    private let progressKey = "com.chronoreader.readingprogress"
    
    private init() {}
    
    // Guardar el progreso de lectura
    func saveProgress(marker: ProgressMarker) {
        var allProgress = getAllProgress()
        
        // Actualizar o añadir el nuevo marcador
        if let index = allProgress.firstIndex(where: { $0.bookId == marker.bookId }) {
            allProgress[index] = marker
        } else {
            allProgress.append(marker)
        }
        
        // Guardar en UserDefaults
        if let encoded = try? JSONEncoder().encode(allProgress) {
            userDefaults.set(encoded, forKey: progressKey)
            userDefaults.synchronize()
        }
    }
    
    // Obtener el progreso de un libro específico
    func getProgress(for bookId: String) -> ProgressMarker? {
        return getAllProgress().first { $0.bookId == bookId }
    }
    
    // Obtener todos los marcadores de progreso
    func getAllProgress() -> [ProgressMarker] {
        guard let data = userDefaults.data(forKey: progressKey),
              let decoded = try? JSONDecoder().decode([ProgressMarker].self, from: data) else {
            return []
        }
        return decoded
    }
    
    // Actualizar el progreso de un libro
    func updateProgress(bookId: String, lastPageRead: Int, totalPageCount: Int, lastPageOffsetPCT: Double? = nil) {
        let marker = ProgressMarker(
            bookId: bookId,
            lastPageRead: lastPageRead,
            totalPageCount: totalPageCount,
            lastPageOffsetPCT: lastPageOffsetPCT
        )
        saveProgress(marker: marker)
    }
    
    // Calcular la posición inicial para un libro
    func getInitialPosition(for bookId: String, limit: Int) -> (Int, CGFloat?) {
        guard let marker = getProgress(for: bookId) else {
            return (0, nil) // No hay marcador, comienza desde el principio
        }
        
        guard let lastPageRead = marker.lastPageRead else {
            return (0, nil)
        }
        
        // Verificar que la página esté dentro de los límites
        guard lastPageRead <= limit, lastPageRead > 0 else {
            return (0, nil)
        }
        
        // Si el capítulo está completado, reinicia
        if lastPageRead == limit {
            return (0, nil)
        }
        
        // Devuelve la página y la posición dentro de la página
        return (lastPageRead - 1, marker.lastPageOffsetPCT.flatMap(CGFloat.init))
    }
}
