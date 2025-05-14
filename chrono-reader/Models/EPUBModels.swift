//
//  EPUBModels.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import Foundation
import SwiftUI

// MARK: - Modelos principales para el lector EPUB

/// Clase principal que representa un libro EPUB
class EPUBBook: Identifiable, ObservableObject {
    let id = UUID()
    var title: String
    var author: String
    var metadata: [String: String]
    var spine: EPUBSpine
    var resources: [String: EPUBResource]
    var tableOfContents: [EPUBTocReference]
    var coverImageURL: URL?
    
    @Published var currentChapterIndex: Int = 0
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var pagedResources: [String: EPUBPagedResource] = [:]
    @Published var totalPositions: Int = 0
    
    init(title: String, author: String, metadata: [String: String], spine: EPUBSpine, resources: [String: EPUBResource], tableOfContents: [EPUBTocReference], coverImageURL: URL? = nil) {
        self.title = title
        self.author = author
        self.metadata = metadata
        self.spine = spine
        self.resources = resources
        self.tableOfContents = tableOfContents
        self.coverImageURL = coverImageURL
        self.totalPages = spine.spineReferences.count
    }
}

/// Representa la columna vertebral del libro (orden de los capítulos)
struct EPUBSpine {
    var spineReferences: [EPUBSpineReference]
    var isRightToLeft: Bool
    
    init(spineReferences: [EPUBSpineReference], isRightToLeft: Bool = false) {
        self.spineReferences = spineReferences
        self.isRightToLeft = isRightToLeft
    }
}

/// Referencia a un capítulo en el spine
struct EPUBSpineReference: Identifiable {
    let id = UUID()
    var resourceId: String
    var linear: Bool
    
    init(resourceId: String, linear: Bool = true) {
        self.resourceId = resourceId
        self.linear = linear
    }
}

/// Representa un recurso en el EPUB (HTML, CSS, imágenes, etc.)
struct EPUBResource: Identifiable {
    let id = UUID()
    var resourceId: String
    var href: String
    var fullHref: String
    var mediaType: EPUBMediaType
    var properties: String?
    var data: Data?
    
    // Para imágenes
    var image: UIImage?
    
    init(resourceId: String, href: String, fullHref: String = "", mediaType: EPUBMediaType, properties: String? = nil, data: Data? = nil) {
        self.resourceId = resourceId
        self.href = href
        self.fullHref = fullHref
        self.mediaType = mediaType
        self.properties = properties
        self.data = data
        
        // Cargar la imagen si es un recurso de imagen
        if EPUBMediaType.isImage(mediaType), let data = data {
            self.image = UIImage(data: data)
        }
    }
    
    /// Verifica si este recurso es una imagen
    var isImage: Bool {
        return EPUBMediaType.isImage(mediaType)
    }
    
    /// Verifica si este recurso es un documento HTML
    var isHTML: Bool {
        return EPUBMediaType.isHTML(mediaType)
    }
    
    /// Carga la imagen si aún no está cargada
    mutating func loadImage() -> UIImage? {
        if isImage && image == nil, let data = data {
            image = UIImage(data: data)
        }
        return image
    }
}

/// Representa un ítem en la tabla de contenidos
struct EPUBTocReference: Identifiable {
    let id = UUID()
    var title: String
    var resourceId: String
    var fragmentId: String?
    var level: Int
    var children: [EPUBTocReference]
    
    init(title: String, resourceId: String, fragmentId: String? = nil, level: Int = 0, children: [EPUBTocReference] = []) {
        self.title = title
        self.resourceId = resourceId
        self.fragmentId = fragmentId
        self.level = level
        self.children = children
    }
}

/// Representa una posición específica en el libro
struct EPUBPosition: Identifiable {
    let id = UUID()
    var resourceId: String
    var progression: Double // 0.0 a 1.0 dentro del recurso
    var totalProgression: Double // 0.0 a 1.0 en todo el libro
    var pageIndex: Int // Índice de página dentro del recurso
    var totalPages: Int // Total de páginas en el recurso
}

/// Representa un recurso paginado
struct EPUBPagedResource {
    var resourceId: String
    var totalPages: Int
    var positions: [EPUBPosition]
    var isRTL: Bool
    var isVertical: Bool
}

// MARK: - Modelos adicionales para el parser

/// Estructura para la configuración del lector
struct EPUBReaderConfig {
    var scrollDirection: EPUBScrollDirection
    var textSize: CGFloat
    var lineHeight: CGFloat
    var fontName: String
    var theme: EPUBReaderTheme
    
    init(scrollDirection: EPUBScrollDirection = .horizontal, 
         textSize: CGFloat = 17, 
         lineHeight: CGFloat = 1.5, 
         fontName: String = "SF Pro Text", 
         theme: EPUBReaderTheme = .light) {
        self.scrollDirection = scrollDirection
        self.textSize = textSize
        self.lineHeight = lineHeight
        self.fontName = fontName
        self.theme = theme
    }
}

/// Dirección de desplazamiento para el lector
enum EPUBScrollDirection {
    case horizontal
    case vertical
}

/// Temas para el lector
enum EPUBReaderTheme {
    case light
    case dark
    case sepia
    
    var backgroundColor: Color {
        switch self {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        case .sepia:
            return Color(red: 0.98, green: 0.94, blue: 0.85)
        }
    }
    
    var textColor: Color {
        switch self {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        case .sepia:
            return Color(red: 0.36, green: 0.24, blue: 0.09)
        }
    }
}

// MARK: - Utilidades de EPUB
// Eliminar la implementación duplicada de EPUBParser aquí 