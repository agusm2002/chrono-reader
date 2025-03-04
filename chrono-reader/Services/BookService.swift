import Foundation
import Combine

protocol BookServiceProtocol {
    func searchComics(query: String) -> AnyPublisher<[Book], Error>
    func searchBooks(query: String) -> AnyPublisher<[Book], Error>
//    func getComicCover(id: String) -> URL? //Eliminado
//    func getBookCover(isbn: String, size: String) -> URL? //Eliminado
}

class BookService: BookServiceProtocol {
    private let shortboxedBaseURL = "https://api.shortboxed.com"
    private let openLibraryBaseURL = "https://openlibrary.org"

    private let decoder: JSONDecoder
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func searchComics(query: String) -> AnyPublisher<[Book], Error> {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(shortboxedBaseURL)/comics/v1/search?query=\(encodedQuery)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ShortBoxedComicResponse.self, decoder: decoder)
            .map { response in
                response.data.map { comic in
                    self.mapComicToBook(comic: comic)
                }
            }
            .eraseToAnyPublisher()
    }

    func searchBooks(query: String) -> AnyPublisher<[Book], Error> {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(openLibraryBaseURL)/search.json?q=\(encodedQuery)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: OpenLibraryResponse.self, decoder: decoder)
            .map { response in
                response.docs?.compactMap { book in
                    self.mapOpenLibraryToBook(book: book)
                } ?? []
            }
            .eraseToAnyPublisher()
    }

//    func getComicCover(id: String) -> URL? {  //Eliminado
//        // ShortBoxed ya proporciona la URL completa en el campo coverImage
//        return URL(string: id)
//    }
//
//    func getBookCover(isbn: String, size: String = "M") -> URL? {  //Eliminado
//        // Tamaños disponibles: S (small), M (medium), L (large)
//        return URL(string: "\(openLibraryBaseURL)/api/covers/isbn/\(isbn)-\(size).jpg")
//    }

    // Métodos auxiliares para mapear respuestas API a nuestro modelo Book
    private func mapComicToBook(comic: ShortBoxedComic) -> Book {
        let author = comic.creators?.first(where: { $0.role.lowercased().contains("writer") })?.name ?? "Unknown"
        let coverImage = comic.coverImage ?? ""

        return Book(
            title: comic.title,
            author: author,
            coverImage: coverImage,
            type: .cbz, // Por defecto asumimos cbz, pero se podría ajustar según metadata
            progress: 0.0,
            isbn: nil,
            publishDate: comic.coverDate,
            publisher: comic.publisher,
            description: comic.description,
            pageCount: nil,
            series: comic.series,
            volume: comic.volume,
            issueNumber: comic.issueNumber
        )
    }

    private func mapOpenLibraryToBook(book: OpenLibraryBook) -> Book? {
        guard let isbn = book.isbn?.first else {
            return nil // Sin ISBN no podemos obtener la portada
        }

        let coverImageURL = "\(openLibraryBaseURL)/api/covers/isbn/\(isbn)-M.jpg"

        return Book(
            title: book.title,
            author: book.author_name?.first ?? "Unknown",
            coverImage: coverImageURL,
            type: .epub, // Por defecto asumimos epub, pero se podría ajustar según metadata
            progress: 0.0,
            isbn: isbn,
            publishDate: book.publish_date?.first,
            publisher: book.publisher?.first,
            description: nil,
            pageCount: book.number_of_pages_median,
            series: nil,
            volume: nil,
            issueNumber: nil
        )
    }
}
