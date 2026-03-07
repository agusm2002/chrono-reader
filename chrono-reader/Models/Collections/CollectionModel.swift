// CollectionModel.swift

import Foundation
import SwiftUI

struct Collection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var books: [UUID] // IDs de los libros en la colección
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorAlpha: Double
    var dateCreated: Date
    
    init(id: UUID = UUID(), name: String, books: [UUID] = [], color: Color = .blue) {
        self.id = id
        self.name = name
        self.books = books
        
        // Extraer componentes del color
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.colorRed = Double(r)
        self.colorGreen = Double(g)
        self.colorBlue = Double(b)
        self.colorAlpha = Double(a)
        self.dateCreated = Date()
    }
    
    // Propiedad calculada para obtener el color
    var color: Color {
        Color(.sRGB, red: colorRed, green: colorGreen, blue: colorBlue, opacity: colorAlpha)
    }
}
