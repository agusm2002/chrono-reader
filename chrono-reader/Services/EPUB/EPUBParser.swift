import Foundation
import XMLCoder

class EPUBParser {
    // Estructuras para el parseo XML
    private struct Container: Decodable {
        let rootfiles: RootFiles
        
        struct RootFiles: Decodable {
            let rootfile: RootFile
            
            struct RootFile: Decodable {
                let fullPath: String
                let mediaType: String
                
                enum CodingKeys: String, CodingKey {
                    case fullPath = "full-path"
                    case mediaType = "media-type"
                }
            }
        }
    }
    
    private struct OPF: Decodable {
        let metadata: Metadata
        let manifest: Manifest
        let spine: Spine
        
        struct Metadata: Decodable {
            let title: String
            let creator: String?
            let language: String?
            let identifier: String
            let rights: String?
            let publisher: String?
            let description: String?
            let date: String?
        }
        
        struct Manifest: Decodable {
            let items: [Item]
            
            struct Item: Decodable {
                let id: String
                let href: String
                let mediaType: String
                let properties: String?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case href
                    case mediaType = "media-type"
                    case properties
                }
            }
        }
        
        struct Spine: Decodable {
            let itemrefs: [ItemRef]
            
            struct ItemRef: Decodable {
                let idref: String
                let properties: String?
            }
        }
    }
    
    static func parseEPUB(at url: URL) throws -> EPUBDocument {
        // 1. Verificar que el directorio existe
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EPUBError.missingContainer
        }
        
        // 2. Parsear container.xml
        let containerURL = url.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBError.missingContainer
        }
        
        let containerData: Data
        do {
            containerData = try Data(contentsOf: containerURL)
        } catch {
            throw EPUBError.invalidContainer
        }
        
        let container: Container
        do {
            container = try XMLDecoder().decode(Container.self, from: containerData)
        } catch {
            throw EPUBError.invalidContainer
        }
        
        // 3. Parsear content.opf
        let opfURL = url.appendingPathComponent(container.rootfiles.rootfile.fullPath)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBError.missingOPF
        }
        
        let opfData: Data
        do {
            opfData = try Data(contentsOf: opfURL)
        } catch {
            throw EPUBError.invalidOPF
        }
        
        let opf: OPF
        do {
            opf = try XMLDecoder().decode(OPF.self, from: opfData)
        } catch {
            throw EPUBError.invalidOPF
        }
        
        // 4. Construir el documento EPUB
        let spineItems = opf.spine.itemrefs.compactMap { itemRef -> EPUBDocument.EPUBSpineItem? in
            guard let manifestItem = opf.manifest.items.first(where: { $0.id == itemRef.idref }) else {
                return nil
            }
            
            return EPUBDocument.EPUBSpineItem(
                id: manifestItem.id,
                href: manifestItem.href,
                title: "", // TODO: Extraer título del contenido HTML
                type: manifestItem.mediaType,
                properties: itemRef.properties?.components(separatedBy: " ") ?? []
            )
        }
        
        let metadata = EPUBDocument.EPUBMetadata(
            title: opf.metadata.title,
            creator: opf.metadata.creator,
            language: opf.metadata.language,
            identifier: opf.metadata.identifier,
            rights: opf.metadata.rights,
            publisher: opf.metadata.publisher,
            description: opf.metadata.description,
            date: opf.metadata.date.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
        
        return EPUBDocument(
            id: opf.metadata.identifier,
            title: opf.metadata.title,
            author: opf.metadata.creator,
            coverImage: nil, // TODO: Implementar extracción de portada
            spine: spineItems,
            metadata: metadata,
            baseURL: opfURL.deletingLastPathComponent()
        )
    }
}
