import Foundation

struct ProgressMarker: Codable {
    var lastPageRead: Int?         // Número de página donde se quedó el usuario
    var totalPageCount: Int?       // Total de páginas del capítulo
    var lastPageOffsetPCT: Double? // Posición vertical dentro de la página (para webtoons)
    var bookId: String             // ID del libro al que pertenece este progreso
    var timestamp: Date            // Fecha y hora de la última actualización
    
    init(bookId: String, lastPageRead: Int? = nil, totalPageCount: Int? = nil, lastPageOffsetPCT: Double? = nil) {
        self.bookId = bookId
        self.lastPageRead = lastPageRead
        self.totalPageCount = totalPageCount
        self.lastPageOffsetPCT = lastPageOffsetPCT
        self.timestamp = Date()
    }
}
