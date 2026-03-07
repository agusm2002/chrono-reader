import Foundation
import UIKit
import Unrar

extension ArchiveHelper {
    class RarController: ArchiveController {
        func getImagePaths(for path: URL) throws -> [String] {
            do {
                print("Obteniendo rutas de imágenes de: \(path.path)")
                let archive = try Archive(path: path.path, password: nil)
                
                let entries = try archive.entries()
                print("Entradas encontradas en el archivo: \(entries.count)")
                
                for (index, entry) in entries.enumerated() {
                    print("Entrada \(index): \(entry.fileName) (directorio: \(entry.directory))")
                }
                
                let files = entries
                    .sorted(by: { $0.fileName < $1.fileName })
                    .filter { !$0.directory && isImagePath($0.fileName) }
                    .map { $0.fileName }
                
                print("Imágenes encontradas: \(files.count)")
                if !files.isEmpty {
                    print("Primera imagen: \(files[0])")
                }
                
                return files
            } catch {
                print("Error al obtener rutas de imágenes: \(error)")
                throw Errors.ArchiveNotFound
            }
        }

        func getImageData(for url: URL, at path: String) throws -> Data {
            do {
                print("Extrayendo datos de imagen: \(path) desde \(url.path)")
                let archive = try Archive(path: url.path, password: nil)
                
                let entries = try archive.entries()
                print("Entradas encontradas: \(entries.count)")
                
                let entry = entries.first(where: {
                    $0.fileName == path
                })
                
                guard let entry else {
                    print("No se encontró la entrada: \(path)")
                    throw ArchiveHelper.Errors.FileNotFound
                }
                
                print("Extrayendo entrada: \(entry.fileName)")
                let data = try archive.extract(entry)
                print("Datos extraídos correctamente: \(data.count) bytes")
                return data
            } catch {
                print("Error al extraer datos de imagen: \(error)")
                throw Errors.ExtractionFailed
            }
        }

        func getItemCount(for path: URL) throws -> Int {
            print("Contando elementos en: \(path.path)")
            do {
                let archive = try Archive(path: path.path, password: nil)
                
                let entries = try archive.entries()
                print("Total de entradas: \(entries.count)")
                
                for (index, entry) in entries.enumerated() {
                    print("Entrada \(index): \(entry.fileName) (directorio: \(entry.directory))")
                }
                
                let imageCount = entries
                    .filter { !$0.directory && isImagePath($0.fileName) }
                    .count
                
                print("Total de imágenes: \(imageCount)")
                return imageCount
            } catch {
                print("Error al contar elementos: \(error)")
                throw Errors.ArchiveNotFound
            }
        }

        func getThumbnailImage(for path: URL) throws -> UIImage {
            do {
                print("Intentando obtener miniatura de: \(path.path)")
                let archive = try Archive(path: path.path, password: nil)
                
                let entries = try archive.entries()
                print("Entradas encontradas: \(entries.count)")
                
                let entry = entries
                    .sorted(by: { $0.fileName < $1.fileName })
                    .first(where: { !$0.directory && isImagePath($0.fileName) })
                
                guard let entry else {
                    print("No se encontró ninguna imagen en el archivo")
                    throw Errors.ArchiveNotFound
                }
                
                print("Extrayendo miniatura: \(entry.fileName)")
                let data = try archive.extract(entry)
                print("Miniatura extraída correctamente: \(data.count) bytes")
                
                guard let image = UIImage(data: data) else {
                    print("No se pudo crear la imagen a partir de los datos")
                    throw Errors.InvalidData
                }
                
                print("Imagen creada correctamente")
                return image
            } catch {
                print("Error al obtener miniatura: \(error)")
                throw Errors.ArchiveNotFound
            }
        }

        func getRARArchive(for path: URL) -> Archive? {
            print("Intentando abrir archivo RAR: \(path.path)")
            do {
                let archive = try Archive(path: path.path, password: nil)
                print("Archivo RAR abierto correctamente")
                
                let entries = try archive.entries()
                print("Entradas encontradas: \(entries.count)")
                
                return archive
            } catch {
                print("Error al abrir archivo RAR: \(error)")
                return nil
            }
        }

        func getThumbnail(for archive: Archive) -> String? {
            do {
                let entries = try archive.entries()
                print("Entradas encontradas en getThumbnail: \(entries.count)")
                
                // Imprimir todas las entradas para depuración
                for (index, entry) in entries.enumerated() {
                    print("Entrada \(index): \(entry.fileName) (directorio: \(entry.directory))")
                }
                
                let entry = entries
                    .sorted(by: { $0.fileName < $1.fileName })
                    .first(where: { !$0.directory && isImagePath($0.fileName) })
                
                if let entry = entry {
                    print("Miniatura encontrada: \(entry.fileName)")
                    return entry.fileName
                } else {
                    print("No se encontró ninguna miniatura")
                    return nil
                }
            } catch {
                print("Error al obtener miniatura: \(error)")
                return nil
            }
        }

        func getComicInfo(for url: URL) throws -> Data? {
            print("Buscando ComicInfo.xml en: \(url.path)")
            do {
                let archive = try Archive(path: url.path, password: nil)
                
                let entries = try archive.entries()
                print("Entradas encontradas: \(entries.count)")
                
                let target = entries
                    .first(where: { !$0.directory && $0.fileName.lowercased().contains("comicinfo.xml") })
                
                if let target = target {
                    print("ComicInfo.xml encontrado: \(target.fileName)")
                    let data = try archive.extract(target)
                    print("ComicInfo.xml extraído correctamente: \(data.count) bytes")
                    return data
                } else {
                    print("No se encontró ComicInfo.xml en el archivo")
                    return nil
                }
            } catch {
                print("Error al obtener ComicInfo.xml: \(error)")
                return nil
            }
        }
    }
}
