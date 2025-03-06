//BookModels.swift

import Foundation
import SwiftUI

enum BookType: String, Codable {
    case epub
    case pdf
    case cbr
    case cbz
}

struct Book: Identifiable, Codable {
    var id = UUID()
    let title: String
    let author: String
    var coverImage: String
    let type: BookType
    var progress: Double // 0.0 to 1.0

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
        Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald", coverImage: "book1", type: .epub, progress: 0.75),
        Book(title: "1984", author: "George Orwell", coverImage: "book2", type: .epub, progress: 0.3),
        Book(title: "Spider-Man: No Way Home", author: "Marvel Comics", coverImage: "comic1", type: .cbz, progress: 0.5),
        Book(title: "Batman: The Dark Knight", author: "DC Comics", coverImage: "comic2", type: .cbr, progress: 0.2),
        Book(title: "Design Patterns", author: "Erich Gamma", coverImage: "book3", type: .pdf, progress: 0.1),
        Book(title: "The Avengers", author: "Marvel Comics", coverImage: "comic3", type: .cbz, progress: 0.9),
        Book(title: "To Kill a Mockingbird", author: "Harper Lee", coverImage: "book4", type: .epub, progress: 0.0),
        Book(title: "Superman: Man of Steel", author: "DC Comics", coverImage: "comic4", type: .cbr, progress: 0.6)
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
    let id = UUID()
    let book: Book
    let metadata: BookMetadata

    init(title: String, author: String, coverImage: String, type: BookType, progress: Double, localURL: URL? = nil, cover: UIImage? = nil) {
        self.book = Book(title: title, author: author, coverImage: coverImage, type: type, progress: progress)
        
        if let cover = cover {
            // Save the image to a local path and store that path
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let imagePath = documentsDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            if let data = cover.jpegData(compressionQuality: 1.0) {
                try? data.write(to: imagePath)
                self.metadata = BookMetadata(localURL: localURL, coverPath: imagePath.path)
            } else {
                self.metadata = BookMetadata(localURL: localURL, coverPath: nil)
            }
        } else {
            self.metadata = BookMetadata(localURL: localURL, coverPath: nil)
        }
    }
    
    static func == (lhs: CompleteBook, rhs: CompleteBook) -> Bool {
        return lhs.id == rhs.id
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
