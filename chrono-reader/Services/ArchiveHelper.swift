import Foundation
import UIKit

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
        
        let controller = getController(for: type)
        
        do {
            let paths = try controller.getImagePaths(for: url)
            print("ArchiveHelper: Encontradas \(paths.count) rutas de imágenes")
            
            var images: [UIImage] = []
            
            for path in paths {
                do {
                    print("ArchiveHelper: Cargando imagen \(path)")
                    let data = try controller.getImageData(for: url, at: path)
                    if let image = UIImage(data: data) {
                        images.append(image)
                        print("ArchiveHelper: Imagen cargada correctamente")
                    } else {
                        print("ArchiveHelper: No se pudo crear la imagen a partir de los datos")
                    }
                } catch {
                    print("ArchiveHelper: Error al cargar la imagen \(path): \(error)")
                }
            }
            
            print("ArchiveHelper: Total de imágenes cargadas: \(images.count)")
            return images
        } catch {
            print("ArchiveHelper: Error al cargar las imágenes: \(error)")
            return []
        }
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
