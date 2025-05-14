//
//  EPUBService.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import Foundation
import SwiftUI
import ZIPFoundation
import XMLCoder

/// Servicio para manejar archivos EPUB
class EPUBService {
    
    /// Parsea un archivo EPUB y devuelve un objeto EPUBBook
    static func parseEPUB(at url: URL) async throws -> EPUBBook {
        // 1. Descomprimir el archivo EPUB (que es un archivo ZIP)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            
            guard let archive = ZipArchive(url: url, accessMode: .read) else {
                throw EPUBError.invalidArchive
            }
            
            // Extraer todos los archivos
            for entry in archive {
                _ = try archive.extract(entry, to: temporaryDirectory.appendingPathComponent(entry.path))
            }
            
            // 2. Leer el archivo container.xml para encontrar el OPF
            let containerURL = temporaryDirectory.appendingPathComponent("META-INF/container.xml")
            guard FileManager.default.fileExists(atPath: containerURL.path) else {
                throw EPUBError.missingContainer
            }
            
            let containerData = try Data(contentsOf: containerURL)
            let container = try XMLDecoder().decode(EPUBContainer.self, from: containerData)
            
            guard let rootFile = container.rootFiles.rootFile.first,
                  let opfPath = rootFile.fullPath else {
                throw EPUBError.invalidContainer
            }
            
            // 3. Leer el archivo OPF
            let opfURL = temporaryDirectory.appendingPathComponent(opfPath)
            guard FileManager.default.fileExists(atPath: opfURL.path) else {
                throw EPUBError.missingOPF
            }
            
            let opfData = try Data(contentsOf: opfURL)
            let opf = try XMLDecoder().decode(EPUBOPF.self, from: opfData)
            
            // 4. Extraer metadatos
            var metadata: [String: String] = [:]
            for meta in opf.metadata.metas {
                if let name = meta.name, let content = meta.content {
                    metadata[name] = content
                }
            }
            
            // Título y autor
            let title = opf.metadata.title?.first?.value ?? "Libro sin título"
            let author = opf.metadata.creator?.first?.value ?? "Autor desconocido"
            
            // 5. Procesar los recursos (manifest)
            var resources: [String: EPUBResource] = [:]
            let baseURL = opfURL.deletingLastPathComponent()
            
            for item in opf.manifest.items {
                guard let id = item.id, let href = item.href else {
                    continue
                }
                
                // Obtener el tipo de medio
                let mediaTypeStr = item.mediaType ?? ""
                let mediaType = EPUBMediaType.by(name: mediaTypeStr, fileName: href)
                
                // Construir la URL completa del recurso
                let resourceURL = baseURL.appendingPathComponent(href)
                let fullHref = resourceURL.path
                var resourceData: Data? = nil
                
                // Cargar los datos del recurso
                if FileManager.default.fileExists(atPath: fullHref) {
                    resourceData = try? Data(contentsOf: resourceURL)
                }
                
                // Crear el recurso
                let resource = EPUBResource(
                    resourceId: id,
                    href: href,
                    fullHref: fullHref,
                    mediaType: mediaType,
                    properties: item.properties,
                    data: resourceData
                )
                
                resources[id] = resource
            }
            
            // 6. Procesar el spine
            var spineReferences: [EPUBSpineReference] = []
            for itemref in opf.spine.itemrefs {
                guard let idref = itemref.idref else { continue }
                let linear = itemref.linear != "no"
                spineReferences.append(EPUBSpineReference(resourceId: idref, linear: linear))
            }
            
            let isRTL = opf.spine.direction == "rtl"
            let spine = EPUBSpine(spineReferences: spineReferences, isRightToLeft: isRTL)
            
            // 7. Procesar la tabla de contenidos (NCX o Nav)
            var tocReferences: [EPUBTocReference] = []
            
            // Buscar el NCX
            let ncxID = opf.spine.toc
            if let ncxID = ncxID, let ncxResource = resources[ncxID], let ncxHref = ncxResource.data {
                // Procesar NCX
                let ncxURL = baseURL.appendingPathComponent(ncxResource.href)
                if let ncxData = try? Data(contentsOf: ncxURL) {
                    let ncx = try? XMLDecoder().decode(EPUBNCX.self, from: ncxData)
                    tocReferences = parseTOCFromNCX(ncx, resources: resources) ?? []
                }
            } else {
                // Buscar Nav en HTML
                for (_, resource) in resources {
                    if resource.mediaType == EPUBMediaType.xhtml, 
                       let data = resource.data,
                       let html = String(data: data, encoding: .utf8),
                       html.contains("<nav") && html.contains("epub:type=\"toc\"") {
                        // Aquí se procesaría el HTML para extraer la tabla de contenidos
                        // Para simplificar, no implementamos esto completo
                        break
                    }
                }
            }
            
            // 8. Buscar la portada
            var coverResource: EPUBResource? = nil
            var coverImageURL: URL? = nil
            
            // Método 1: Buscar por id específico en los metadatos
            if let coverId = metadata["cover"], let coverRes = resources[coverId], coverRes.isImage {
                coverResource = coverRes
                coverImageURL = URL(fileURLWithPath: coverRes.fullHref)
            } 
            // Método 2: Buscar por propiedad "cover-image"
            else {
                coverResource = resources.values.first { 
                    $0.isImage && $0.properties?.contains("cover-image") == true 
                }
                
                if let coverRes = coverResource {
                    coverImageURL = URL(fileURLWithPath: coverRes.fullHref)
                }
            }
            
            // Método 3: Si no se encuentra por metadatos, buscar en la tabla de contenidos
            if coverResource == nil {
                // Buscar posibles recursos de imagen que tengan "cover" en su ID o ruta
                let potentialCovers = resources.values.filter { 
                    $0.isImage && 
                    ($0.resourceId.lowercased().contains("cover") || 
                     $0.href.lowercased().contains("cover"))
                }
                
                if let firstCover = potentialCovers.first {
                    coverResource = firstCover
                    coverImageURL = URL(fileURLWithPath: firstCover.fullHref)
                }
            }
            
            // Método 4: Si todo lo demás falla, usar la primera imagen del libro
            if coverResource == nil {
                if let firstImage = resources.values.first(where: { $0.isImage }) {
                    coverResource = firstImage
                    coverImageURL = URL(fileURLWithPath: firstImage.fullHref)
                }
            }
            
            // 9. Crear el libro EPUB
            let book = EPUBBook(
                title: title,
                author: author,
                metadata: metadata,
                spine: spine,
                resources: resources,
                tableOfContents: tocReferences,
                coverImageURL: coverImageURL
            )
            
            // 10. Procesar las posiciones
            return processPositions(for: book)
            
        } catch {
            // Limpiar directorio temporal
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        }
    }
    
    /// Parsea la tabla de contenidos desde un archivo NCX
    private static func parseTOCFromNCX(_ ncx: EPUBNCX?, resources: [String: EPUBResource]) -> [EPUBTocReference]? {
        guard let navMap = ncx?.navMap, let navPoints = navMap.navPoints else {
            return nil
        }
        
        return navPoints.compactMap { navPoint in
            guard let label = navPoint.navLabel?.text,
                  let content = navPoint.content,
                  let src = content.src else {
                return nil
            }
            
            // Separar la referencia del fragmento
            let components = src.components(separatedBy: "#")
            let href = components[0]
            let fragment = components.count > 1 ? components[1] : nil
            
            // Buscar el ID del recurso por href
            let resourceId = resources.first { $0.value.href == href }?.key ?? ""
            
            // Procesar hijos recursivamente
            var children: [EPUBTocReference] = []
            if let childNavPoints = navPoint.navPoints {
                for childPoint in childNavPoints {
                    if let childLabel = childPoint.navLabel?.text,
                       let childContent = childPoint.content,
                       let childSrc = childContent.src {
                        let childComponents = childSrc.components(separatedBy: "#")
                        let childHref = childComponents[0]
                        let childFragment = childComponents.count > 1 ? childComponents[1] : nil
                        let childResourceId = resources.first { $0.value.href == childHref }?.key ?? ""
                        
                        children.append(EPUBTocReference(
                            title: childLabel,
                            resourceId: childResourceId,
                            fragmentId: childFragment,
                            level: 1
                        ))
                    }
                }
            }
            
            return EPUBTocReference(
                title: label,
                resourceId: resourceId,
                fragmentId: fragment,
                level: 0,
                children: children
            )
        }
    }
    
    /// Calcula las posiciones y páginas para un recurso HTML
    private static func calculatePositions(for resource: EPUBResource, 
                                         spine: EPUBSpine,
                                         totalBytes: Int) -> EPUBPagedResource? {
        guard let data = resource.data,
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Calcular el número de posiciones basado en el tamaño del recurso
        let resourceBytes = data.count
        let positionsCount = max(1, Int(Double(resourceBytes) / 1024.0)) // 1 posición por cada 1KB
        
        // Crear las posiciones
        var positions: [EPUBPosition] = []
        for i in 0..<positionsCount {
            let progression = Double(i) / Double(positionsCount - 1)
            let totalProgression = Double(resourceBytes) / Double(totalBytes)
            
            positions.append(EPUBPosition(
                resourceId: resource.resourceId,
                progression: progression,
                totalProgression: totalProgression,
                pageIndex: i,
                totalPages: positionsCount
            ))
        }
        
        // Determinar si es RTL o vertical
        let isRTL = spine.isRightToLeft
        let isVertical = content.contains("writing-mode: vertical")
        
        return EPUBPagedResource(
            resourceId: resource.resourceId,
            totalPages: positionsCount,
            positions: positions,
            isRTL: isRTL,
            isVertical: isVertical
        )
    }
    
    /// Calcula el número total de bytes en el libro
    private static func calculateTotalBytes(for resources: [String: EPUBResource]) -> Int {
        return resources.values.reduce(0) { $0 + ($1.data?.count ?? 0) }
    }
    
    /// Procesa el libro para calcular todas las posiciones
    private static func processPositions(for book: EPUBBook) -> EPUBBook {
        let totalBytes = calculateTotalBytes(for: book.resources)
        var pagedResources: [String: EPUBPagedResource] = [:]
        var totalPositions = 0
        
        // Procesar cada recurso HTML
        for spineRef in book.spine.spineReferences {
            if let resource = book.resources[spineRef.resourceId],
               resource.isHTML,
               let pagedResource = calculatePositions(for: resource, 
                                                    spine: book.spine,
                                                    totalBytes: totalBytes) {
                pagedResources[spineRef.resourceId] = pagedResource
                totalPositions += pagedResource.totalPages
            }
        }
        
        // Actualizar el libro
        book.pagedResources = pagedResources
        book.totalPositions = totalPositions
        
        return book
    }
    
    static func loadEPUB(from url: URL) throws -> EPUBDocument {
        // 1. Crear un directorio temporal para descomprimir el EPUB
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        do {
            // 2. Crear el directorio temporal
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            
            // 3. Descomprimir el EPUB
            guard let archive = Archive(url: url, accessMode: .read) else {
                throw EPUBError.invalidArchive
            }
            
            // 4. Extraer todos los archivos
            for entry in archive {
                _ = try archive.extract(entry, to: temporaryDirectory.appendingPathComponent(entry.path))
            }
            
            // 5. Parsear el EPUB descomprimido
            let document = try EPUBParser.parseEPUB(at: temporaryDirectory)
            
            // 6. Limpiar el directorio temporal
            try? FileManager.default.removeItem(at: temporaryDirectory)
            
            return document
        } catch {
            // Limpiar el directorio temporal en caso de error
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        }
    }
    
    static func extractContent(from spineItem: EPUBDocument.EPUBSpineItem, baseURL: URL) throws -> String {
        let contentURL = baseURL.appendingPathComponent(spineItem.href)
        let content = try String(contentsOf: contentURL, encoding: .utf8)
        
        // TODO: Implementar procesamiento del HTML para mejorar la visualización
        // Por ahora, simplemente devolvemos el contenido HTML crudo
        return content
    }
    
    static func extractCoverImage(from document: EPUBDocument) -> Data? {
        // TODO: Implementar extracción de imagen de portada
        return nil
    }
}

// MARK: - Modelos para XML
/// Contenedor EPUB
struct EPUBContainer: Codable {
    let rootFiles: RootFiles
    
    enum CodingKeys: String, CodingKey {
        case rootFiles = "rootfiles"
    }
    
    struct RootFiles: Codable {
        let rootFile: [RootFile]
        
        enum CodingKeys: String, CodingKey {
            case rootFile = "rootfile"
        }
    }
    
    struct RootFile: Codable {
        let fullPath: String?
        let mediaType: String?
        
        enum CodingKeys: String, CodingKey {
            case fullPath = "full-path"
            case mediaType = "media-type"
        }
    }
}

/// OPF (Open Package Format)
struct EPUBOPF: Codable {
    let metadata: EPUBMetadata
    let manifest: EPUBManifest
    let spine: EPUBOPFSpine
}

struct EPUBMetadata: Codable {
    let title: [EPUBText]?
    let creator: [EPUBText]?
    let language: [EPUBText]?
    let metas: [EPUBMeta]
    
    enum CodingKeys: String, CodingKey {
        case title, creator, language
        case metas = "meta"
    }
}

struct EPUBText: Codable {
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case value = ""
    }
}

struct EPUBMeta: Codable {
    let name: String?
    let content: String?
}

struct EPUBManifest: Codable {
    let items: [EPUBItem]
    
    enum CodingKeys: String, CodingKey {
        case items = "item"
    }
}

struct EPUBItem: Codable {
    let id: String?
    let href: String?
    let mediaType: String?
    let properties: String?
    
    enum CodingKeys: String, CodingKey {
        case id, href, properties
        case mediaType = "media-type"
    }
}

struct EPUBOPFSpine: Codable {
    let itemrefs: [EPUBItemref]
    let toc: String?
    let direction: String?
    
    enum CodingKeys: String, CodingKey {
        case itemrefs = "itemref"
        case toc, direction
    }
}

struct EPUBItemref: Codable {
    let idref: String?
    let linear: String?
}

/// NCX (Navigation Control file for XML)
struct EPUBNCX: Codable {
    let navMap: NavMap?
    
    enum CodingKeys: String, CodingKey {
        case navMap = "navMap"
    }
    
    struct NavMap: Codable {
        let navPoints: [NavPoint]?
        
        enum CodingKeys: String, CodingKey {
            case navPoints = "navPoint"
        }
    }
    
    struct NavPoint: Codable {
        let id: String?
        let playOrder: String?
        let navLabel: NavLabel?
        let content: Content?
        let navPoints: [NavPoint]?
        
        enum CodingKeys: String, CodingKey {
            case id, playOrder, navLabel, content
            case navPoints = "navPoint"
        }
    }
    
    struct NavLabel: Codable {
        let text: String?
    }
    
    struct Content: Codable {
        let src: String?
    }
}

// MARK: - Errores
enum EPUBError: Error {
    case invalidArchive
    case missingContainer
    case invalidContainer
    case missingOPF
    case invalidOPF
    case missingNCX
    case invalidNCX
} 