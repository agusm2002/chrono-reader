//BookModels.swift

import Foundation
import SwiftUI

enum BookType: String, Codable {
    case epub
    case pdf
    case cbr
    case cbz
    case m4b
}

struct Book: Identifiable, Codable {
    var id = UUID()
    let title: String
    let author: String
    var coverImage: String
    let type: BookType
    var progress: Double // 0.0 to 1.0
    var lastReadDate: Date? // Fecha de última lectura
    var isFavorite: Bool = false // Nuevo campo para marcar como favorito
    var isRecent: Bool = false // Campo para marcar libros recientes

    // Metadata
    var isbn: String?
    var publishDate: String?
    var publisher: String?
    var description: String?
    var pageCount: Int?
    var series: String?
    var volume: String?
    var issueNumber: Int?

    // Para cargar la imagen desde una URL
    var coverURL: URL? {
        return URL(string: coverImage)
    }

    // Sample data for preview
    static let samples = [
        Book(title: "El Principito", author: "Antoine de Saint-Exupéry", coverImage: "book1", type: .epub, progress: 0.0, lastReadDate: nil),
        Book(title: "Batman: Year One", author: "Frank Miller", coverImage: "comic2", type: .cbr, progress: 0.0, lastReadDate: nil),
        Book(title: "Spider-Man: Miles Morales", author: "Marvel Comics", coverImage: "comic1", type: .cbz, progress: 0.0, lastReadDate: nil)
    ]
}

struct BookMetadata: Codable {
    var localURL: URL?
    var coverPath: String?

    init(localURL: URL? = nil, coverPath: String? = nil) {
        self.localURL = localURL
        self.coverPath = coverPath
    }
}

struct CompleteBook: Identifiable, Codable, Equatable {
    let id: UUID
    let book: Book
    let metadata: BookMetadata
    let lastPageOffsetPCT: Double?
    let comicReaderSettings: ComicReaderSettings?

    init(id: UUID = UUID(), title: String, author: String, coverImage: String, type: BookType, progress: Double, localURL: URL? = nil, cover: UIImage? = nil, lastReadDate: Date? = nil, lastPageOffsetPCT: Double? = nil, comicReaderSettings: ComicReaderSettings? = nil, isFavorite: Bool = false) {
        self.id = id
        self.book = Book(title: title, author: author, coverImage: coverImage, type: type, progress: progress, lastReadDate: lastReadDate, isFavorite: isFavorite)
        self.lastPageOffsetPCT = lastPageOffsetPCT
        self.comicReaderSettings = comicReaderSettings
        
        if let cover = cover {
            // Save the image to a local path and store that path
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let coverFileName = "\(id.uuidString)-cover.jpg"
            let imagePath = documentsDirectory.appendingPathComponent(coverFileName)
            
            if let data = cover.jpegData(compressionQuality: 0.9) {
                do {
                    // Asegurarse de que el directorio existe
                    try FileManager.default.createDirectory(
                        at: documentsDirectory,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    // Escribir la imagen al archivo
                    try data.write(to: imagePath)
                    print("Portada guardada en: \(imagePath.path)")
                    self.metadata = BookMetadata(localURL: localURL, coverPath: imagePath.path)
                } catch {
                    print("Error al guardar la portada: \(error)")
                    self.metadata = BookMetadata(localURL: localURL, coverPath: nil)
                }
            } else {
                print("No se pudo convertir la imagen a datos JPEG")
                self.metadata = BookMetadata(localURL: localURL, coverPath: nil)
            }
        } else {
            self.metadata = BookMetadata(localURL: localURL, coverPath: nil)
        }
    }
    
    // Método para obtener la imagen de portada
    func getCoverImage() -> UIImage? {
        if let coverPath = metadata.coverPath {
            if FileManager.default.fileExists(atPath: coverPath) {
                if let image = UIImage(contentsOfFile: coverPath) {
                    return image
                } else {
                    print("No se pudo cargar la imagen de: \(coverPath)")
                }
            } else {
                print("El archivo de portada no existe: \(coverPath)")
            }
        }
        return nil
    }
    
    // Método para actualizar la portada
    func withUpdatedCover(_ cover: UIImage?) -> CompleteBook {
        return CompleteBook(
            id: id,
            title: book.title,
            author: book.author,
            coverImage: book.coverImage,
            type: book.type,
            progress: book.progress,
            localURL: metadata.localURL,
            cover: cover,
            lastReadDate: book.lastReadDate,
            lastPageOffsetPCT: lastPageOffsetPCT,
            comicReaderSettings: comicReaderSettings,
            isFavorite: book.isFavorite
        )
    }
    
    // Método para actualizar el progreso
    func withUpdatedProgress(_ progress: Double) -> CompleteBook {
        // Crear una copia del libro con el progreso actualizado
        var bookCopy = book
        bookCopy.progress = progress
        bookCopy.lastReadDate = Date() // Actualizar la fecha de última lectura
        
        print("Actualizando progreso en withUpdatedProgress: \(progress * 100)%")
        
        return CompleteBook(
            id: id,
            title: bookCopy.title,
            author: bookCopy.author,
            coverImage: bookCopy.coverImage,
            type: bookCopy.type,
            progress: progress,
            localURL: metadata.localURL,
            cover: getCoverImage(), // Mantener la portada existente
            lastReadDate: bookCopy.lastReadDate,
            lastPageOffsetPCT: lastPageOffsetPCT,
            comicReaderSettings: comicReaderSettings,
            isFavorite: bookCopy.isFavorite
        )
    }
    
    // Método para actualizar el estado de favorito
    func withUpdatedFavorite(_ isFavorite: Bool) -> CompleteBook {
        var bookCopy = book
        bookCopy.isFavorite = isFavorite
        
        return CompleteBook(
            id: id,
            title: bookCopy.title,
            author: bookCopy.author,
            coverImage: bookCopy.coverImage,
            type: bookCopy.type,
            progress: bookCopy.progress,
            localURL: metadata.localURL,
            cover: getCoverImage(),
            lastReadDate: bookCopy.lastReadDate,
            lastPageOffsetPCT: lastPageOffsetPCT,
            comicReaderSettings: comicReaderSettings,
            isFavorite: isFavorite
        )
    }

    func withUpdatedComicReaderSettings(_ settings: ComicReaderSettings?) -> CompleteBook {
        return CompleteBook(
            id: id,
            title: book.title,
            author: book.author,
            coverImage: book.coverImage,
            type: book.type,
            progress: book.progress,
            localURL: metadata.localURL,
            cover: getCoverImage(),
            lastReadDate: book.lastReadDate,
            lastPageOffsetPCT: lastPageOffsetPCT,
            comicReaderSettings: settings,
            isFavorite: book.isFavorite
        )
    }
    
    static func == (lhs: CompleteBook, rhs: CompleteBook) -> Bool {
        return lhs.id == rhs.id
    }
}

// Extensión para manejar títulos personalizados
extension CompleteBook {
    // Obtener el título para mostrar (personalizado o original)
    var displayTitle: String {
        // Buscar si hay un título personalizado
        if let customTitle = CustomTitleService.shared.getCustomTitle(for: id) {
            return customTitle
        }
        // Si no, devolver el título original
        return book.title
    }
    
    // Actualizar el título personalizado
    func updateCustomTitle(_ newTitle: String) {
        CustomTitleService.shared.saveCustomTitle(bookId: id, title: newTitle)
    }
    
    // Eliminar el título personalizado
    func removeCustomTitle() {
        CustomTitleService.shared.removeCustomTitle(for: id)
    }
}

// API Models for ShortBoxed (Comics)
struct ShortBoxedComicResponse: Codable {
    let data: [ShortBoxedComic]
}

struct ShortBoxedComic: Codable {
    let title: String
    let issueNumber: Int?
    let coverDate: String?
    let publisher: String?
    let creators: [ShortBoxedCreator]?
    let coverImage: String?
    let description: String?
    let series: String?
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case title, publisher, description, series, volume
        case issueNumber = "issue_number"
        case coverDate = "cover_date"
        case creators
        case coverImage = "cover_image"
    }
}

struct ShortBoxedCreator: Codable {
    let name: String
    let role: String
}

// API Models for OpenLibrary (Books)
struct OpenLibraryResponse: Codable {
    let docs: [OpenLibraryBook]?
}

struct OpenLibraryBook: Codable {
    let title: String
    let author_name: [String]?
    let isbn: [String]?
    let publisher: [String]?
    let publish_date: [String]?
    let number_of_pages_median: Int?
}
