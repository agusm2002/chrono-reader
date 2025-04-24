//
//  EPUBViewerViewModel.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import Foundation
import SwiftUI
import Combine

class EPUBViewerViewModel: ObservableObject {
    // Referencia al libro completo
    private let bookReference: CompleteBook
    
    // Datos del EPUB
    @Published var epubBook: EPUBBook?
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var readingProgress: Double = 0.0
    @Published var isLoading: Bool = true
    @Published var readerConfig: EPUBReaderConfig = EPUBReaderConfig()
    
    // Propiedades de navegación
    @Published private(set) var currentChapterIndex: Int = 0
    @Published private(set) var currentChapterTitle: String = ""
    @Published private(set) var progressText: String = ""
    @Published private(set) var tableOfContents: [EPUBTocReference] = []
    
    // Caché de contenido de capítulos
    private var chaptersContent: [String: String] = [:]
    
    // Cancellables para Combine
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var currentPosition: Int = 0
    @Published var currentResourceId: String = ""
    @Published var currentPageInResource: Int = 0
    
    init(book: CompleteBook) {
        self.bookReference = book
        
        // Configurar tema inicial basado en el esquema de color del sistema
        if UITraitCollection.current.userInterfaceStyle == .dark {
            readerConfig.theme = .dark
        }
        
        // Observar cambios en la página actual para actualizar el progreso
        $currentPage
            .sink { [weak self] page in
                guard let self = self, let epubBook = self.epubBook else { return }
                self.updateReadingProgress()
                self.updateProgressText()
                self.saveProgress()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Carga del libro
    
    /// Carga el libro EPUB desde la URL
    func loadBook() async {
        guard let localURL = bookReference.metadata.localURL else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            let book = try await EPUBService.parseEPUB(at: localURL)
            
            await MainActor.run {
                self.epubBook = book
                self.totalPages = book.spine.spineReferences.count
                self.tableOfContents = book.tableOfContents
                
                // Restaurar progreso si existe
                if let lastPageOffset = bookReference.lastPageOffsetPCT, lastPageOffset > 0 {
                    let estimatedPage = Int(lastPageOffset * Double(self.totalPages))
                    self.currentPage = max(0, min(estimatedPage, self.totalPages - 1))
                }
                
                // Cargar contenido de los capítulos
                Task {
                    await self.preloadChapters()
                    await MainActor.run {
                        self.updateCurrentChapter()
                        self.isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                print("Error al cargar el libro EPUB: \(error)")
                self.isLoading = false
            }
        }
    }
    
    /// Precarga el contenido de los capítulos en segundo plano
    private func preloadChapters() async {
        guard let epubBook = epubBook else { return }
        
        for spineRef in epubBook.spine.spineReferences {
            if let resource = epubBook.resources[spineRef.resourceId], 
               let data = resource.data,
               let content = String(data: data, encoding: .utf8) {
                // Procesar el contenido HTML
                let processedContent = processHTMLContent(content, resourceId: spineRef.resourceId)
                chaptersContent[spineRef.resourceId] = processedContent
            }
        }
    }
    
    /// Procesa el contenido HTML para adaptarlo al lector
    private func processHTMLContent(_ html: String, resourceId: String) -> String {
        guard let epubBook = epubBook else { return html }
        
        var processedHTML = html
        
        // Eliminar etiquetas <head> para aplicar nuestros propios estilos
        if let headRange = html.range(of: "<head[^>]*>.*?</head>", options: .regularExpression) {
            processedHTML = html.replacingOccurrences(of: html[headRange], with: "")
        }
        
        // Eliminar etiquetas <script> para seguridad
        processedHTML = processedHTML.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: .regularExpression
        )
        
        // Identificar la ruta base del recurso actual
        if let currentResource = epubBook.resources[resourceId] {
            let resourceHref = currentResource.href
            let resourceBasePath = (resourceHref as NSString).deletingLastPathComponent
            let baseURL = currentResource.fullHref
            
            // Arreglar rutas relativas en imágenes
            processedHTML = processImageURLs(processedHTML, basePath: resourceBasePath, resources: epubBook.resources)
            
            // Arreglar rutas relativas en enlaces
            processedHTML = processLinkURLs(processedHTML, basePath: resourceBasePath, resources: epubBook.resources)
            
            // Arreglar rutas relativas en hojas de estilo
            processedHTML = processStylesheetURLs(processedHTML, basePath: resourceBasePath, resources: epubBook.resources)
        }
        
        return processedHTML
    }
    
    /// Procesa las URLs de imágenes para convertirlas en rutas absolutas
    private func processImageURLs(_ html: String, basePath: String, resources: [String: EPUBResource]) -> String {
        var processedHTML = html
        
        // Patrón para buscar etiquetas <img> con src relativo
        let imgPattern = "<img[^>]*src\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>"
        
        do {
            let regex = try NSRegularExpression(pattern: imgPattern, options: .caseInsensitive)
            let nsString = processedHTML as NSString
            let matches = regex.matches(in: processedHTML, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Procesar desde atrás para no afectar las posiciones
            for match in matches.reversed() {
                let fullMatch = nsString.substring(with: match.range)
                if match.numberOfRanges >= 2 {
                    let srcRange = match.range(at: 1)
                    let src = nsString.substring(with: srcRange)
                    
                    // Si la URL ya es absoluta, no la modificamos
                    if src.hasPrefix("http") || src.hasPrefix("file") || src.hasPrefix("/") {
                        continue
                    }
                    
                    // Construir la ruta relativa completa
                    let relativePath = basePath.isEmpty ? src : "\(basePath)/\(src)"
                    
                    // Buscar el recurso correspondiente
                    if let imgResource = resources.values.first(where: { $0.href == relativePath || $0.href == src }) {
                        // Reemplazar con la ruta completa
                        let replacement = fullMatch.replacingOccurrences(of: src, with: "file://\(imgResource.fullHref)")
                        processedHTML = (processedHTML as NSString).replacingCharacters(in: match.range, with: replacement)
                    }
                }
            }
        } catch {
            print("Error procesando imágenes: \(error)")
        }
        
        return processedHTML
    }
    
    /// Procesa las URLs de enlaces para convertirlas en rutas absolutas
    private func processLinkURLs(_ html: String, basePath: String, resources: [String: EPUBResource]) -> String {
        var processedHTML = html
        
        // Patrón para buscar etiquetas <a> con href relativo
        let linkPattern = "<a[^>]*href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>"
        
        do {
            let regex = try NSRegularExpression(pattern: linkPattern, options: .caseInsensitive)
            let nsString = processedHTML as NSString
            let matches = regex.matches(in: processedHTML, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullMatch = nsString.substring(with: match.range)
                if match.numberOfRanges >= 2 {
                    let hrefRange = match.range(at: 1)
                    let href = nsString.substring(with: hrefRange)
                    
                    // Manejar enlaces internos a fragmentos
                    if href.hasPrefix("#") {
                        continue
                    }
                    
                    // Si la URL ya es absoluta, no la modificamos
                    if href.hasPrefix("http") || href.hasPrefix("file") || href.hasPrefix("/") {
                        continue
                    }
                    
                    // Construir la ruta relativa completa
                    let relativePath = basePath.isEmpty ? href : "\(basePath)/\(href)"
                    
                    // Buscar el recurso correspondiente
                    if let linkResource = resources.values.first(where: { $0.href == relativePath || $0.href == href }) {
                        // Reemplazar con la ruta completa
                        let replacement = fullMatch.replacingOccurrences(of: href, with: "file://\(linkResource.fullHref)")
                        processedHTML = (processedHTML as NSString).replacingCharacters(in: match.range, with: replacement)
                    }
                }
            }
        } catch {
            print("Error procesando enlaces: \(error)")
        }
        
        return processedHTML
    }
    
    /// Procesa las URLs de hojas de estilo para convertirlas en rutas absolutas
    private func processStylesheetURLs(_ html: String, basePath: String, resources: [String: EPUBResource]) -> String {
        var processedHTML = html
        
        // Patrón para buscar etiquetas <link> con href de hojas de estilo
        let linkPattern = "<link[^>]*href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>"
        
        do {
            let regex = try NSRegularExpression(pattern: linkPattern, options: .caseInsensitive)
            let nsString = processedHTML as NSString
            let matches = regex.matches(in: processedHTML, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullMatch = nsString.substring(with: match.range)
                if match.numberOfRanges >= 2 {
                    let hrefRange = match.range(at: 1)
                    let href = nsString.substring(with: hrefRange)
                    
                    // Si la URL ya es absoluta, no la modificamos
                    if href.hasPrefix("http") || href.hasPrefix("file") || href.hasPrefix("/") {
                        continue
                    }
                    
                    // Construir la ruta relativa completa
                    let relativePath = basePath.isEmpty ? href : "\(basePath)/\(href)"
                    
                    // Buscar el recurso correspondiente
                    if let cssResource = resources.values.first(where: { $0.href == relativePath || $0.href == href }) {
                        // Reemplazar con la ruta completa
                        let replacement = fullMatch.replacingOccurrences(of: href, with: "file://\(cssResource.fullHref)")
                        processedHTML = (processedHTML as NSString).replacingCharacters(in: match.range, with: replacement)
                    }
                }
            }
        } catch {
            print("Error procesando hojas de estilo: \(error)")
        }
        
        return processedHTML
    }
    
    // MARK: - Navegación
    
    /// Actualiza el capítulo actual basado en la página actual
    func updateCurrentChapter() {
        guard let epubBook = epubBook, currentPage < epubBook.spine.spineReferences.count else { return }
        
        let spineRef = epubBook.spine.spineReferences[currentPage]
        currentChapterIndex = currentPage
        
        // Buscar el título del capítulo en la tabla de contenidos
        for tocItem in tableOfContents {
            if tocItem.resourceId == spineRef.resourceId {
                currentChapterTitle = tocItem.title
                return
            }
            
            // Buscar en los hijos
            for childItem in tocItem.children {
                if childItem.resourceId == spineRef.resourceId {
                    currentChapterTitle = childItem.title
                    return
                }
            }
        }
        
        // Si no se encuentra en la TOC, usar un título genérico
        currentChapterTitle = "Capítulo \(currentPage + 1)"
    }
    
    /// Navega al siguiente capítulo
    func nextChapter() {
        guard let epubBook = epubBook else { return }
        
        let nextPage = currentPage + 1
        if nextPage < totalPages {
            withAnimation {
                currentPage = nextPage
            }
        }
    }
    
    /// Navega al capítulo anterior
    func previousChapter() {
        let prevPage = currentPage - 1
        if prevPage >= 0 {
            withAnimation {
                currentPage = prevPage
            }
        }
    }
    
    /// Navega a un capítulo específico por su ID de recurso
    func navigateToChapter(resourceId: String) {
        guard let epubBook = epubBook else { return }
        
        for (index, spineRef) in epubBook.spine.spineReferences.enumerated() {
            if spineRef.resourceId == resourceId {
                withAnimation {
                    currentPage = index
                }
                return
            }
        }
    }
    
    /// Verifica si un ID de recurso corresponde al capítulo actual
    func isCurrentChapter(_ resourceId: String) -> Bool {
        guard let epubBook = epubBook, currentPage < epubBook.spine.spineReferences.count else { return false }
        
        let currentResourceId = epubBook.spine.spineReferences[currentPage].resourceId
        return currentResourceId == resourceId
    }
    
    // MARK: - Contenido y progreso
    
    /// Obtiene el contenido HTML para una página específica
    func getPageContent(for pageIndex: Int) -> String? {
        guard let epubBook = epubBook, pageIndex < epubBook.spine.spineReferences.count else { return nil }
        
        let spineRef = epubBook.spine.spineReferences[pageIndex]
        
        // Intentar recuperar del caché
        if let cachedContent = chaptersContent[spineRef.resourceId] {
            return cachedContent
        }
        
        // Si no está en caché, cargarlo
        if let resource = epubBook.resources[spineRef.resourceId], 
           let data = resource.data,
           let content = String(data: data, encoding: .utf8) {
            let processedContent = processHTMLContent(content, resourceId: spineRef.resourceId)
            chaptersContent[spineRef.resourceId] = processedContent
            return processedContent
        }
        
        return nil
    }
    
    /// Actualiza el progreso de lectura basado en la posición actual
    func updateReadingProgress() {
        guard let epubBook = epubBook,
              let pagedResource = epubBook.pagedResources[currentResourceId],
              pagedResource.totalPages > 0 else {
            readingProgress = 0.0
            return
        }
        
        // Calcular progreso dentro del recurso actual
        let resourceProgress = Double(currentPageInResource) / Double(pagedResource.totalPages - 1)
        
        // Calcular progreso total
        let position = currentPosition
        let totalPositions = epubBook.totalPositions
        readingProgress = totalPositions > 0 ? Double(position) / Double(totalPositions - 1) : 0.0
        
        // Actualizar texto de progreso
        updateProgressText()
    }
    
    /// Actualiza el texto de progreso
    private func updateProgressText() {
        guard let epubBook = epubBook,
              let pagedResource = epubBook.pagedResources[currentResourceId] else {
            progressText = "0%"
            return
        }
        
        let percentage = Int(readingProgress * 100)
        progressText = "\(percentage)% • Página \(currentPageInResource + 1)/\(pagedResource.totalPages)"
    }
    
    /// Guarda el progreso de lectura
    private func saveProgress() {
        // Notificar al sistema sobre el progreso actualizado
        NotificationCenter.default.post(
            name: Notification.Name("BookProgressUpdated"),
            object: nil,
            userInfo: [
                "book": bookReference.withUpdatedProgress(readingProgress)
            ]
        )
    }
    
    /// Navega a la siguiente página
    func nextPage() {
        guard let epubBook = epubBook,
              let pagedResource = epubBook.pagedResources[currentResourceId] else { return }
        
        if currentPageInResource < pagedResource.totalPages - 1 {
            // Hay más páginas en el recurso actual
            currentPageInResource += 1
            currentPosition += 1
            updateReadingProgress()
        } else {
            // Buscar el siguiente recurso
            if let nextResourceId = findNextResource() {
                navigateToResource(nextResourceId, pageIndex: 0)
            }
        }
    }
    
    /// Navega a la página anterior
    func previousPage() {
        guard let epubBook = epubBook,
              let pagedResource = epubBook.pagedResources[currentResourceId] else { return }
        
        if currentPageInResource > 0 {
            // Hay páginas anteriores en el recurso actual
            currentPageInResource -= 1
            currentPosition -= 1
            updateReadingProgress()
        } else {
            // Buscar el recurso anterior
            if let previousResourceId = findPreviousResource() {
                if let previousResource = epubBook.pagedResources[previousResourceId] {
                    navigateToResource(previousResourceId, pageIndex: previousResource.totalPages - 1)
                }
            }
        }
    }
    
    /// Encuentra el siguiente recurso en el spine
    private func findNextResource() -> String? {
        guard let epubBook = epubBook else { return nil }
        
        for (index, spineRef) in epubBook.spine.spineReferences.enumerated() {
            if spineRef.resourceId == currentResourceId {
                let nextIndex = index + 1
                if nextIndex < epubBook.spine.spineReferences.count {
                    return epubBook.spine.spineReferences[nextIndex].resourceId
                }
                break
            }
        }
        
        return nil
    }
    
    /// Encuentra el recurso anterior en el spine
    private func findPreviousResource() -> String? {
        guard let epubBook = epubBook else { return nil }
        
        for (index, spineRef) in epubBook.spine.spineReferences.enumerated() {
            if spineRef.resourceId == currentResourceId {
                let previousIndex = index - 1
                if previousIndex >= 0 {
                    return epubBook.spine.spineReferences[previousIndex].resourceId
                }
                break
            }
        }
        
        return nil
    }
    
    /// Navega a un recurso específico y página
    private func navigateToResource(_ resourceId: String, pageIndex: Int) {
        guard let epubBook = epubBook,
              let pagedResource = epubBook.pagedResources[resourceId] else { return }
        
        // Calcular la nueva posición
        var newPosition = 0
        for spineRef in epubBook.spine.spineReferences {
            if spineRef.resourceId == resourceId {
                break
            }
            if let resource = epubBook.pagedResources[spineRef.resourceId] {
                newPosition += resource.totalPages
            }
        }
        newPosition += pageIndex
        
        // Actualizar estado
        currentResourceId = resourceId
        currentPageInResource = pageIndex
        currentPosition = newPosition
        currentPage = findSpineIndex(for: resourceId) ?? 0
        
        updateReadingProgress()
    }
    
    /// Encuentra el índice en el spine para un recurso
    private func findSpineIndex(for resourceId: String) -> Int? {
        guard let epubBook = epubBook else { return nil }
        
        for (index, spineRef) in epubBook.spine.spineReferences.enumerated() {
            if spineRef.resourceId == resourceId {
                return index
            }
        }
        
        return nil
    }
} 