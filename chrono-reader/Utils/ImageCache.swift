import SwiftUI
import Foundation
import CoreGraphics
import ImageIO

// Clase singleton para gestión de caché de imágenes
class ImageCache {
    static let shared = ImageCache()
    
    // Caché efectiva: almacena imágenes por ruta
    private var cache = NSCache<NSString, UIImage>()
    
    // Evitar instanciación externa, patrón singleton
    private init() {
        // Configurar límites de caché basados en memoria disponible
        cache.countLimit = 100 // Número máximo de imágenes en caché
        
        // Recibir notificaciones de memoria baja
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Limpiar caché (manual o en advertencias de memoria)
    @objc func clearCache() {
        cache.removeAllObjects()
    }
    
    // Obtener imagen desde caché o cargar si no existe
    func image(for path: String, size: CGSize) -> UIImage? {
        // Generar clave para la caché que incluya la ruta y el tamaño
        let key = "\(path)_\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Verificar si existe en caché
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }
        
        // Si no existe, cargar y hacer downsampling
        guard let originalImage = UIImage(contentsOfFile: path) else {
            return nil
        }
        
        // Aplicar downsampling para el tamaño específico
        let downsampledImage = downsampleImage(originalImage, to: size)
        
        // Guardar en caché
        cache.setObject(downsampledImage, forKey: key)
        
        return downsampledImage
    }
    
    // Función de optimización de imágenes con downsampling
    private func downsampleImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        // Calcular escala basada en el tamaño de la pantalla
        let scale = UIScreen.main.scale
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * scale
        
        // Opciones para eficiencia
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        
        // Crear fuente de imagen
        guard let data = image.pngData(),
              let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return image
        }
        
        // Opciones de thumbnail con downsampling
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        // Generar y devolver imagen reducida
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return image
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}

// Extensión de vista para facilitar el uso de imágenes en caché
struct CachedImage: View {
    let imagePath: String
    let targetSize: CGSize
    
    var body: some View {
        Group {
            if let image = ImageCache.shared.image(for: imagePath, size: targetSize) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder mientras carga
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// Extensión para mejorar la carga de portadas de libros
extension CompleteBook {
    func coverImage(size: CGSize) -> UIImage? {
        guard let coverPath = metadata.coverPath else {
            return nil
        }
        
        return ImageCache.shared.image(for: coverPath, size: size)
    }
} 