import Foundation
import UIKit
import ZIPFoundation

extension ArchiveHelper {
    class ZipController: ArchiveController {
        func getImagePaths(for path: URL) throws -> [String] {
            print("ZipController: Obteniendo rutas de imágenes para \(path.path)")
            guard let archive = getZIPArchive(for: path) else {
                print("ZipController: No se pudo abrir el archivo ZIP")
                throw Errors.ArchiveNotFound
            }

            let files = archive
                .sorted(by: { $0.path < $1.path })
                .filter { $0.type == .file && isImagePath($0.path) }
                .map { $0.path }
            
            print("ZipController: Encontradas \(files.count) imágenes")
            if !files.isEmpty {
                print("ZipController: Primera imagen: \(files[0])")
            }

            return files
        }

        func getItemCount(for path: URL) throws -> Int {
            print("ZipController: Contando imágenes en \(path.path)")
            guard let archive = getZIPArchive(for: path) else {
                print("ZipController: No se pudo abrir el archivo ZIP")
                throw Errors.ArchiveNotFound
            }
            
            let count = archive
                .filter { $0.type == .file && isImagePath($0.path) }
                .count
                
            print("ZipController: Total imágenes: \(count)")
            return count
        }

        func getThumbnailImage(for path: URL) throws -> UIImage {
            print("ZipController: Obteniendo miniatura para \(path.path)")
            guard let archive = getZIPArchive(for: path) else {
                print("ZipController: No se pudo abrir el archivo ZIP")
                throw Errors.ArchiveNotFound
            }

            let thumbnailPath = getThumbnail(for: archive)

            guard let thumbnailPath else {
                print("ZipController: No se encontró ninguna imagen para usar como miniatura")
                throw Errors.ArchiveNotFound
            }

            print("ZipController: Usando \(thumbnailPath) como miniatura")
            let imageData = try getImageData(for: path, at: thumbnailPath)

            guard let image = UIImage(data: imageData) else {
                print("ZipController: No se pudo crear imagen a partir de los datos")
                throw Errors.InvalidData
            }

            return image
        }

        func getZIPArchive(for path: URL) -> Archive? {
            do {
                // Verificar primero si el archivo existe y es accesible
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: path.path) {
                    print("ZipController: El archivo no existe en la ruta: \(path.path)")
                    return nil
                }
                
                // Intentar abrir el archivo como ZIP de manera segura
                // Asegurarse de que el archivo es legible
                let attrs = try fileManager.attributesOfItem(atPath: path.path)
                print("ZipController: Tamaño del archivo: \(attrs[.size] ?? "desconocido")")
                
                // Intentar abrir el archivo
                guard let archive = Archive(url: path, accessMode: .read) else {
                    print("ZipController: No se pudo abrir el archivo como ZIP válido")
                    return nil
                }
                
                print("ZipController: Archivo ZIP abierto correctamente: \(path.lastPathComponent)")
                return archive
            } catch {
                print("ZipController: Error al acceder al archivo: \(error)")
                return nil
            }
        }

        func getThumbnail(for archive: Archive) -> String? {
            let entry = archive
                .sorted(by: { $0.path < $1.path })
                .first(where: { $0.type == .file && isImagePath($0.path) })
            if let entry = entry {
                return entry.path
            }

            return nil
        }

        func getImageData(for url: URL, at path: String) throws -> Data {
            print("ZipController: Extrayendo datos de imagen \(path)")
            guard let archive = getZIPArchive(for: url), let file = archive[path] else {
                print("ZipController: No se pudo abrir el archivo o no se encontró la entrada")
                throw ArchiveHelper.Errors.ArchiveNotFound
            }

            var out = Data()

            do {
                _ = try archive.extract(file) { data in
                    out.append(data)
                }
                print("ZipController: Imagen extraída correctamente: \(out.count) bytes")
                return out
            } catch {
                print("ZipController: Error al extraer datos: \(error)")
                throw Errors.ExtractionFailed
            }
        }

        func getComicInfo(for url: URL) throws -> Data? {
            print("ZipController: Buscando ComicInfo.xml en \(url.path)")
            guard let archive = getZIPArchive(for: url) else {
                print("ZipController: No se pudo abrir el archivo ZIP")
                throw Errors.ArchiveNotFound
            }

            let target = archive
                .first(where: { entry in
                    entry.type == .file && entry.path.lowercased().contains("comicinfo.xml")
                })

            guard let target else {
                print("ZipController: No se encontró ComicInfo.xml")
                return nil // Return nil if file does not have info.xml
            }

            print("ZipController: ComicInfo.xml encontrado: \(target.path)")
            var out = Data()

            do {
                _ = try archive.extract(target) { data in
                    out.append(data)
                }
                print("ZipController: ComicInfo.xml extraído correctamente: \(out.count) bytes")
                return out
            } catch {
                print("ZipController: Error al extraer ComicInfo.xml: \(error)")
                throw Errors.ExtractionFailed
            }
        }
    }
}
