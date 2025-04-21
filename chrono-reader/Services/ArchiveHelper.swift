import Foundation
import UIKit
import ZIPFoundation

// Clase auxiliar para manejar archivos de cómic comprimidos
class ArchiveHelper {
    
    // Errores comunes al trabajar con archivos
    enum Errors: Error {
        case ArchiveNotFound
        case FileNotFound
        case InvalidData
        case ExtractionFailed
        case UnsupportedFormat
    }
    
    // Protocolo que deben implementar todos los controladores de archivos
    protocol ArchiveController {
        // Obtener las rutas de las imágenes dentro del archivo
        func getImagePaths(for path: URL) throws -> [String]
        
        // Obtener los datos de una imagen específica dentro del archivo
        func getImageData(for url: URL, at path: String) throws -> Data
        
        // Obtener el número total de imágenes en el archivo
        func getItemCount(for path: URL) throws -> Int
        
        // Obtener la imagen de portada del archivo
        func getThumbnailImage(for path: URL) throws -> UIImage
        
        // Verificar si una ruta corresponde a una imagen
        func isImagePath(_ path: String) -> Bool
        
        // Obtener los datos del archivo ComicInfo.xml si existe
        func getComicInfo(for url: URL) throws -> Data?
    }
    
    // Método para obtener el controlador adecuado según el tipo de archivo
    static func getController(for type: BookType) -> ArchiveController {
        switch type {
        case .cbz:
            return ZipController()
        case .cbr:
            return RarController()
        case .epub:
            return EpubController()
        default:
            fatalError("Tipo de archivo no soportado: \(type)")
        }
    }
    
    // Método para cargar todas las imágenes de un archivo
    static func loadImages(from url: URL, type: BookType) -> [UIImage] {
        print("ArchiveHelper: Cargando imágenes de \(url.path) (tipo: \(type.rawValue))")
        
        // Para tipos de archivo no soportados por el visor de cómics
        if type == .epub || type == .pdf {
            print("ArchiveHelper: Tipo de archivo no soportado para visor de cómics: \(type.rawValue)")
            return []
        }
        
        // Verificar que el archivo existe
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            print("ArchiveHelper: El archivo no existe en la ruta especificada: \(url.path)")
            return []
        }
        
        let controller = getController(for: type)
        
        do {
            // Imprimir información sobre el archivo
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? NSNumber {
                    print("ArchiveHelper: Tamaño del archivo: \(fileSize.intValue) bytes")
                }
            } catch {
                print("ArchiveHelper: No se pudo obtener información del archivo: \(error)")
            }
            
            print("ArchiveHelper: Obteniendo rutas de imágenes...")
            let paths = try controller.getImagePaths(for: url)
            print("ArchiveHelper: Encontradas \(paths.count) rutas de imágenes")
            
            if paths.isEmpty {
                print("ArchiveHelper: No se encontraron imágenes en el archivo")
                return []
            }
            
            var images: [UIImage] = []
            
            // Crear un contador para mostrar progreso
            var processedCount = 0
            let totalCount = paths.count
            
            for path in paths {
                do {
                    print("ArchiveHelper: Cargando imagen [\(processedCount+1)/\(totalCount)]: \(path)")
                    let data = try controller.getImageData(for: url, at: path)
                    if let image = UIImage(data: data) {
                        images.append(image)
                        print("ArchiveHelper: Imagen cargada correctamente (\(data.count) bytes)")
                    } else {
                        print("ArchiveHelper: No se pudo crear la imagen a partir de los datos")
                    }
                    processedCount += 1
                } catch {
                    print("ArchiveHelper: Error al cargar la imagen \(path): \(error)")
                }
            }
            
            print("ArchiveHelper: Total de imágenes cargadas: \(images.count) de \(paths.count)")
            return images
        } catch {
            print("ArchiveHelper: Error al cargar las imágenes: \(error)")
            
            // Intentar un método alternativo si el normal falla
            if type == .cbz {
                print("ArchiveHelper: Intentando método alternativo para CBZ")
                return loadImagesFromZipAlternative(url: url)
            }
            
            return []
        }
    }
    
    // Método alternativo para cargar imágenes de archivos ZIP
    private static func loadImagesFromZipAlternative(url: URL) -> [UIImage] {
        print("ArchiveHelper: Método alternativo para cargar imágenes de ZIP: \(url.path)")
        guard let archive = ZIPFoundation.Archive(url: url, accessMode: .read) else {
            print("ArchiveHelper: No se pudo abrir el archivo ZIP (método alternativo)")
            return []
        }
        
        var images: [UIImage] = []
        
        // Obtener todas las entradas que son imágenes
        let imageEntries = archive.sorted { $0.path < $1.path }
            .filter { entry in
                let path = entry.path.lowercased()
                return entry.type == .file && (
                    path.hasSuffix(".jpg") || 
                    path.hasSuffix(".jpeg") || 
                    path.hasSuffix(".png") || 
                    path.hasSuffix(".gif") || 
                    path.hasSuffix(".webp") || 
                    path.hasSuffix(".bmp")
                )
            }
        
        print("ArchiveHelper: Encontradas \(imageEntries.count) imágenes (método alternativo)")
        
        for entry in imageEntries {
            do {
                print("ArchiveHelper: Cargando imagen (método alternativo): \(entry.path)")
                var data = Data()
                try archive.extract(entry) { data.append($0) }
                
                if let image = UIImage(data: data) {
                    images.append(image)
                    print("ArchiveHelper: Imagen cargada correctamente (método alternativo)")
                } else {
                    print("ArchiveHelper: No se pudo crear la imagen a partir de los datos (método alternativo)")
                }
            } catch {
                print("ArchiveHelper: Error al extraer la imagen (método alternativo): \(error)")
            }
        }
        
        print("ArchiveHelper: Total de imágenes cargadas (método alternativo): \(images.count)")
        return images
    }
}

// Extensión por defecto para implementar métodos comunes
extension ArchiveHelper.ArchiveController {
    func isImagePath(_ path: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        let isImage = imageExtensions.contains(pathExtension)
        if isImage {
            print("Archivo de imagen encontrado: \(path)")
        }
        return isImage
    }
}
