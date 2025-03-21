//
//  EPUBMediaType.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import Foundation

/// Clase para manejar los tipos de medios en EPUB
struct EPUBMediaType: Equatable {
    let name: String
    let defaultExtension: String
    let extensions: [String]
    
    init(name: String, defaultExtension: String, extensions: [String]? = nil) {
        self.name = name
        self.defaultExtension = defaultExtension
        self.extensions = extensions ?? [defaultExtension]
    }
    
    static func == (lhs: EPUBMediaType, rhs: EPUBMediaType) -> Bool {
        return lhs.name == rhs.name
    }
    
    // Tipos de medios comunes en EPUB
    
    // Contenido principal
    static let xhtml = EPUBMediaType(name: "application/xhtml+xml", defaultExtension: "xhtml", extensions: ["xhtml", "html", "htm", "xml"])
    static let html = EPUBMediaType(name: "text/html", defaultExtension: "html", extensions: ["html", "htm"])
    static let xml = EPUBMediaType(name: "application/xml", defaultExtension: "xml")
    static let css = EPUBMediaType(name: "text/css", defaultExtension: "css")
    static let js = EPUBMediaType(name: "text/javascript", defaultExtension: "js")
    
    // Imágenes
    static let jpg = EPUBMediaType(name: "image/jpeg", defaultExtension: "jpg", extensions: ["jpg", "jpeg"])
    static let png = EPUBMediaType(name: "image/png", defaultExtension: "png")
    static let gif = EPUBMediaType(name: "image/gif", defaultExtension: "gif")
    static let svg = EPUBMediaType(name: "image/svg+xml", defaultExtension: "svg")
    static let webp = EPUBMediaType(name: "image/webp", defaultExtension: "webp")
    
    // Audio
    static let mp3 = EPUBMediaType(name: "audio/mpeg", defaultExtension: "mp3")
    static let mp4Audio = EPUBMediaType(name: "audio/mp4", defaultExtension: "mp4")
    static let ogg = EPUBMediaType(name: "audio/ogg", defaultExtension: "ogg")
    
    // Video
    static let mp4Video = EPUBMediaType(name: "video/mp4", defaultExtension: "mp4")
    static let webm = EPUBMediaType(name: "video/webm", defaultExtension: "webm")
    
    // Fuentes
    static let otf = EPUBMediaType(name: "application/vnd.ms-opentype", defaultExtension: "otf")
    static let ttf = EPUBMediaType(name: "application/font-sfnt", defaultExtension: "ttf")
    static let woff = EPUBMediaType(name: "application/font-woff", defaultExtension: "woff")
    static let woff2 = EPUBMediaType(name: "application/font-woff2", defaultExtension: "woff2")
    
    // Metadatos
    static let ncx = EPUBMediaType(name: "application/x-dtbncx+xml", defaultExtension: "ncx")
    static let opf = EPUBMediaType(name: "application/oebps-package+xml", defaultExtension: "opf")
    
    // Todos los tipos
    static let allTypes: [EPUBMediaType] = [
        xhtml, html, xml, css, js,
        jpg, png, gif, svg, webp,
        mp3, mp4Audio, ogg,
        mp4Video, webm,
        otf, ttf, woff, woff2,
        ncx, opf
    ]
    
    // MARK: - Utilidades
    
    /// Determina si es una imagen de mapa de bits
    static func isBitmapImage(_ mediaType: EPUBMediaType) -> Bool {
        return mediaType == jpg || mediaType == png || mediaType == gif || mediaType == webp
    }
    
    /// Determina si es una imagen vectorial
    static func isVectorImage(_ mediaType: EPUBMediaType) -> Bool {
        return mediaType == svg
    }
    
    /// Determina si es cualquier tipo de imagen
    static func isImage(_ mediaType: EPUBMediaType) -> Bool {
        return isBitmapImage(mediaType) || isVectorImage(mediaType)
    }
    
    /// Determina si es un documento HTML/XHTML
    static func isHTML(_ mediaType: EPUBMediaType) -> Bool {
        return mediaType == html || mediaType == xhtml
    }
    
    /// Obtener el tipo de medio por nombre o extensión
    static func by(name: String, fileName: String? = nil) -> EPUBMediaType {
        // Primero, buscar por nombre exacto
        if let foundType = allTypes.first(where: { $0.name == name }) {
            return foundType
        }
        
        // Si tenemos un nombre de archivo, intentar determinar por extensión
        if let fileName = fileName {
            let ext = (fileName as NSString).pathExtension.lowercased()
            for type in allTypes {
                if type.extensions.contains(ext) {
                    return type
                }
            }
        }
        
        // Si no se encuentra, devolver HTML como predeterminado para documentos
        return html
    }
} 