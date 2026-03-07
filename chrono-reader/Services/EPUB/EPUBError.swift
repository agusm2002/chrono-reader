import Foundation

enum EPUBError: Error {
    case invalidArchive
    case missingContainer
    case invalidContainer
    case missingOPF
    case invalidOPF
}
