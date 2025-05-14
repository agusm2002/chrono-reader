import Foundation

struct EPUBDocument {
    let id: String
    let title: String
    let author: String?
    let coverImage: Data?
    let spine: [EPUBSpineItem]
    let metadata: EPUBMetadata
    let baseURL: URL
    
    struct EPUBSpineItem {
        let id: String
        let href: String
        let title: String
        let type: String
        let properties: [String]
    }
    
    struct EPUBMetadata {
        let title: String
        let creator: String?
        let language: String?
        let identifier: String
        let rights: String?
        let publisher: String?
        let description: String?
        let date: Date?
    }
} 