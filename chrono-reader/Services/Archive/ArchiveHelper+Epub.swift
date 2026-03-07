import Foundation
import UIKit
import ZIPFoundation

// Controlador para archivos EPUB (que son básicamente archivos ZIP)
class EpubController: ArchiveHelper.ArchiveController {
    
    // Obtener las rutas de las imágenes dentro del archivo EPUB
    func getImagePaths(for path: URL) throws -> [String] {
        print("EpubController: Obteniendo rutas de imágenes para \(path.path)")
        
        guard let archive = ZIPFoundation.Archive(url: path, accessMode: .read) else {
            print("EpubController: No se pudo abrir el archivo EPUB")
            throw ArchiveHelper.Errors.ArchiveNotFound
        }
        
        // Filtrar solo las entradas que son imágenes
        let imagePaths = archive.filter { isImagePath($0.path) }
            .map { $0.path }
            .sorted()
        
        print("EpubController: Encontradas \(imagePaths.count) imágenes")
        return imagePaths
    }
    
    // Obtener los datos de una imagen específica dentro del archivo
    func getImageData(for url: URL, at path: String) throws -> Data {
        print("EpubController: Obteniendo datos de imagen para \(path)")
        
        guard let archive = ZIPFoundation.Archive(url: url, accessMode: .read) else {
            print("EpubController: No se pudo abrir el archivo EPUB")
            throw ArchiveHelper.Errors.ArchiveNotFound
        }
        
        guard let entry = archive[path] else {
            print("EpubController: No se encontró la entrada \(path)")
            throw ArchiveHelper.Errors.FileNotFound
        }
        
        var data = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            return data
        } catch {
            print("EpubController: Error al extraer datos: \(error)")
            throw ArchiveHelper.Errors.ExtractionFailed
        }
    }
    
    // Obtener el número total de imágenes en el archivo
    func getItemCount(for path: URL) throws -> Int {
        print("EpubController: Obteniendo recuento de imágenes para \(path.path)")
        
        let paths = try getImagePaths(for: path)
        return paths.count
    }
    
    // Obtener la imagen de portada del archivo
    func getThumbnailImage(for path: URL) throws -> UIImage {
        print("EpubController: Obteniendo imagen de portada para \(path.path)")
        
        guard let archive = ZIPFoundation.Archive(url: path, accessMode: .read) else {
            print("EpubController: No se pudo abrir el archivo EPUB")
            throw ArchiveHelper.Errors.ArchiveNotFound
        }
        
        // Buscar la portada en ubicaciones comunes de EPUB
        let coverPaths = [
            "OEBPS/cover.jpg",
            "OEBPS/cover.jpeg",
            "OEBPS/cover.png",
            "OEBPS/images/cover.jpg",
            "OEBPS/images/cover.jpeg",
            "OEBPS/images/cover.png",
            "OPS/cover.jpg",
            "OPS/cover.jpeg",
            "OPS/cover.png",
            "OPS/images/cover.jpg",
            "OPS/images/cover.jpeg",
            "OPS/images/cover.png"
        ]
        
        // Intentar encontrar la portada en las ubicaciones comunes
        for coverPath in coverPaths {
            if let entry = archive[coverPath] {
                var data = Data()
                do {
                    _ = try archive.extract(entry) { chunk in
                        data.append(chunk)
                    }
                    if let image = UIImage(data: data) {
                        print("EpubController: Portada encontrada en \(coverPath)")
                        return image
                    }
                } catch {
                    print("EpubController: Error al extraer portada de \(coverPath): \(error)")
                }
            }
        }
        
        // Si no se encuentra en las ubicaciones comunes, buscar en el contenido del EPUB
        // Primero buscar en el archivo content.opf para encontrar la referencia a la portada
        if let contentEntry = archive.first(where: { $0.path.hasSuffix("content.opf") }) {
            var contentData = Data()
            do {
                _ = try archive.extract(contentEntry) { chunk in
                    contentData.append(chunk)
                }
                
                if let contentXML = String(data: contentData, encoding: .utf8) {
                    // Buscar referencias a la portada en el XML
                    if let coverID = extractCoverID(from: contentXML) {
                        print("EpubController: ID de portada encontrado: \(coverID)")
                        
                        // Buscar la ruta del archivo de portada usando el ID
                        if let coverPath = findCoverPath(in: contentXML, withID: coverID) {
                            print("EpubController: Ruta de portada encontrada: \(coverPath)")
                            
                            // Determinar la ruta completa
                            let basePath = contentEntry.path.components(separatedBy: "/").dropLast().joined(separator: "/")
                            let fullPath = basePath.isEmpty ? coverPath : "\(basePath)/\(coverPath)"
                            
                            if let entry = archive[fullPath] {
                                var data = Data()
                                _ = try archive.extract(entry) { chunk in
                                    data.append(chunk)
                                }
                                if let image = UIImage(data: data) {
                                    print("EpubController: Portada extraída de \(fullPath)")
                                    return image
                                }
                            }
                        }
                    }
                }
            } catch {
                print("EpubController: Error al procesar content.opf: \(error)")
            }
        }
        
        // Si todo lo anterior falla, usar la primera imagen del archivo como portada
        do {
            let imagePaths = try getImagePaths(for: path)
            if let firstImagePath = imagePaths.first {
                let data = try getImageData(for: path, at: firstImagePath)
                if let image = UIImage(data: data) {
                    print("EpubController: Usando primera imagen como portada: \(firstImagePath)")
                    return image
                }
            }
        } catch {
            print("EpubController: Error al buscar primera imagen: \(error)")
        }
        
        print("EpubController: No se pudo encontrar ninguna portada")
        throw ArchiveHelper.Errors.FileNotFound
    }
    
    // Obtener los datos del archivo ComicInfo.xml si existe (no aplicable para EPUB)
    func getComicInfo(for url: URL) throws -> Data? {
        return nil
    }
    
    // Función auxiliar para extraer el ID de la portada del archivo content.opf
    private func extractCoverID(from contentXML: String) -> String? {
        // Buscar patrones comunes para la referencia de portada
        let patterns = [
            "<meta name=\"cover\" content=\"([^\"]+)\"",
            "<item id=\"cover\" href=\"([^\"]+)\"",
            "<item id=\"([^\"]+)\"[^>]*properties=\"cover-image\""
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(contentXML.startIndex..<contentXML.endIndex, in: contentXML)
                if let match = regex.firstMatch(in: contentXML, options: [], range: range) {
                    if let range = Range(match.range(at: 1), in: contentXML) {
                        return String(contentXML[range])
                    }
                }
            }
        }
        
        return nil
    }
    
    // Función auxiliar para encontrar la ruta de la portada usando su ID
    private func findCoverPath(in contentXML: String, withID coverID: String) -> String? {
        let pattern = "<item[^>]*id=\"\(coverID)\"[^>]*href=\"([^\"]+)\""
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(contentXML.startIndex..<contentXML.endIndex, in: contentXML)
            if let match = regex.firstMatch(in: contentXML, options: [], range: range) {
                if let range = Range(match.range(at: 1), in: contentXML) {
                    return String(contentXML[range])
                }
            }
        }
        
        return nil
    }
    
    // Verificar si una ruta corresponde a una imagen
    func isImagePath(_ path: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        return imageExtensions.contains(pathExtension)
    }
}
