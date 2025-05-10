//
//  EPUBViewerViewModel.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import Foundation
import SwiftUI
import Combine
import WebKit

// Estructura para mapear cada página global a su recurso y página interna
struct GlobalPageIndex {
    let resourceId: String
    let pageInResource: Int
}

// Utilidad para extraer nodos principales del HTML
fileprivate func extractHtmlBlocks(_ html: String) -> [String] {
    // Extrae bloques principales: <p>, <div>, <h1-6>, <img>, <hr>, <ul>, <ol>, <li>, <blockquote>, <pre>
    let pattern = #"(<p[\s\S]*?>[\s\S]*?</p>|<div[\s\S]*?>[\s\S]*?</div>|<h[1-6][^>]*>[\s\S]*?</h[1-6]>|<img[\s\S]*?>|<hr[\s\S]*?>|<ul[\s\S]*?>[\s\S]*?</ul>|<ol[\s\S]*?>[\s\S]*?</ol>|<li[\s\S]*?>[\s\S]*?</li>|<blockquote[\s\S]*?>[\s\S]*?</blockquote>|<pre[\s\S]*?>[\s\S]*?</pre>)"#
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        var blocks: [String] = []
        var lastEnd = 0
        for match in matches {
            let range = match.range
            // Agregar texto entre bloques como <p>
            if range.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: range.location - lastEnd)
                let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append("<p>\(text)</p>")
                }
            }
            let block = nsString.substring(with: range)
            blocks.append(block)
            lastEnd = range.location + range.length
        }
        // Agregar texto restante
        if lastEnd < nsString.length {
            let textRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
            let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append("<p>\(text)</p>")
            }
        }
        return blocks
    } catch {
        // Si hay error, dividir por párrafos
        return html.components(separatedBy: "</p>")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0 + "</p>" }
    }
}

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
    @Published var currentResourceId: String? = nil
    @Published var currentPageInResource: Int = 0
    
    // Caché de páginas por recurso
    private var pageCache: [String: [String]] = [:]
    
    // Índice global de páginas
    private var globalPageIndex: [GlobalPageIndex] = []
    
    // Array global de todas las páginas del libro
    private var allPages: [String] = []
    
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
                self.tableOfContents = book.tableOfContents
                // Cargar y paginar todo el libro
                Task {
                    await self.preloadChapters()
                    await MainActor.run {
                        self.paginateAllContent()
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
    
    /// Construye el índice global de páginas
    private func buildGlobalPageIndex() {
        globalPageIndex = []
        totalPages = 0
        guard let epubBook = epubBook else { return }
        
        for spineRef in epubBook.spine.spineReferences {
            // Paginar el recurso
            if let resource = epubBook.resources[spineRef.resourceId],
               let data = resource.data,
               let content = String(data: data, encoding: .utf8) {
                let processedContent = processHTMLContent(content, resourceId: spineRef.resourceId)
                let paginator = SmartPagination(
                    content: processedContent,
                    fontSize: CGFloat(readerConfig.textSize),
                    lineHeight: readerConfig.lineHeight,
                    pageWidth: UIScreen.main.bounds.width,
                    pageHeight: UIScreen.main.bounds.height,
                    horizontalMargin: 40,
                    verticalMargin: 40
                )
                let pages = paginator.calculatePages()
                // Guardar en caché
                pageCache[spineRef.resourceId] = pages
                // Agregar al índice global
                for (i, _) in pages.enumerated() {
                    globalPageIndex.append(GlobalPageIndex(resourceId: spineRef.resourceId, pageInResource: i))
                }
                totalPages += pages.count
            }
        }
    }
    
    /// Pagina todo el contenido del libro
    private func paginateAllContent() {
        guard let epubBook = epubBook else { return }
        
        // Limpiar cachés
        pageCache.removeAll()
        globalPageIndex.removeAll()
        allPages.removeAll()
        
        var currentGlobalPage = 0
        
        // Procesar cada recurso en el spine
        for spineRef in epubBook.spine.spineReferences {
            guard let resource = epubBook.resources[spineRef.resourceId],
                  let content = chaptersContent[spineRef.resourceId] else { continue }
            
            let maxPageSize = 5000 // Tamaño máximo aproximado por página
            // Preprocesar solo los bloques <p> grandes: dividirlos en sub-bloques de máximo 800 caracteres sin cortar palabras
            let maxParagraphSize = 800
            var processedBlocks: [String] = []
            for block in extractHtmlBlocks(content) {
                // Solo dividir si es un <p> grande
                if block.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<p") && block.count > maxParagraphSize {
                    var start = block.startIndex
                    while start < block.endIndex {
                        let end = block.index(start, offsetBy: maxParagraphSize, limitedBy: block.endIndex) ?? block.endIndex
                        var subBlock = String(block[start..<end])
                        // No cortar palabras si no es el final
                        if end < block.endIndex, let lastSpace = subBlock.lastIndex(of: " ") {
                            let safeEnd = block.index(start, offsetBy: subBlock.distance(from: subBlock.startIndex, to: lastSpace))
                            subBlock = String(block[start..<safeEnd])
                            processedBlocks.append(subBlock)
                            start = block.index(after: safeEnd)
                            continue
                        }
                        processedBlocks.append(subBlock)
                        start = end
                    }
                } else {
                    processedBlocks.append(block)
                }
            }
            // Paginación estándar con los bloques procesados
            var pages: [String] = []
            var currentPageBlocks: [String] = []
            var currentPageSize = 0
            for block in processedBlocks {
                let blockSize = block.count
                if blockSize > maxPageSize {
                    let pageContent = block
                    pages.append(pageContent)
                    globalPageIndex.append(GlobalPageIndex(resourceId: spineRef.resourceId, pageInResource: pages.count - 1))
                    continue
                }
                if currentPageSize + blockSize > maxPageSize && !currentPageBlocks.isEmpty {
                    let pageContent = currentPageBlocks.joined(separator: "\n")
                    pages.append(pageContent)
                    globalPageIndex.append(GlobalPageIndex(resourceId: spineRef.resourceId, pageInResource: pages.count - 1))
                    currentPageBlocks = []
                    currentPageSize = 0
                }
                currentPageBlocks.append(block)
                currentPageSize += blockSize;
            }
            if !currentPageBlocks.isEmpty {
                let pageContent = currentPageBlocks.joined(separator: "\n")
                pages.append(pageContent)
                globalPageIndex.append(GlobalPageIndex(resourceId: spineRef.resourceId, pageInResource: pages.count - 1))
            }
            pageCache[spineRef.resourceId] = pages
            allPages.append(contentsOf: pages)
        }
        
        // Actualizar el total de páginas
        totalPages = allPages.count
    }
    
    /// Obtiene el contenido de una página específica
    func getPageContent(for position: Int) -> String? {
        guard position >= 0 && position < globalPageIndex.count else { return nil }
        
        let pageIndex = globalPageIndex[position]
        return pageCache[pageIndex.resourceId]?[pageIndex.pageInResource]
    }
    
    /// Actualiza la configuración del lector
    func updateReaderConfig(_ config: EPUBReaderConfig) {
        readerConfig = config
        paginateAllContent()
    }
    
    /// Actualiza el progreso de lectura basado en la posición actual
    func updateReadingProgress() {
        guard let epubBook = epubBook,
              let currentResourceId = currentResourceId,
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
              let currentResourceId = currentResourceId,
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
              let currentResourceId = currentResourceId,
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
              let currentResourceId = currentResourceId,
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

// Estructura para manejar la paginación inteligente
struct SmartPagination {
    let content: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let horizontalMargin: CGFloat
    let verticalMargin: CGFloat
    
    var contentWidth: CGFloat {
        pageWidth - (2 * horizontalMargin)
    }
    
    var contentHeight: CGFloat {
        pageHeight - (2 * verticalMargin)
    }
    
    func calculatePages() -> [String] {
        let blocks = extractHtmlBlocks(content)
        var pages: [String] = []
        var currentPage = ""
        var currentHeight: CGFloat = 0
        let lineHeightPx = fontSize * lineHeight
        let charsPerLine = max(10, Int(contentWidth / (fontSize * 0.6)))
        
        for block in blocks {
            let text = block.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            let blockLines = estimateLines(for: text, charsPerLine: charsPerLine)
            let blockHeight = CGFloat(blockLines) * lineHeightPx
            
            // Si el bloque es más grande que una página, dividirlo
            if blockHeight > contentHeight {
                let lines = splitTextIntoLines(text, charsPerLine: charsPerLine)
                var remainingLines = lines
                
                while !remainingLines.isEmpty {
                    var pageLines: [String] = []
                    var pageHeight: CGFloat = 0
                    
                    // Llenar la página actual
                    while !remainingLines.isEmpty && pageHeight + lineHeightPx <= contentHeight {
                        let line = remainingLines.removeFirst()
                        pageLines.append(line)
                        pageHeight += lineHeightPx
                    }
                    
                    // Si quedan líneas y la página está casi llena, mover la última línea a la siguiente página
                    if !remainingLines.isEmpty && pageHeight + lineHeightPx > contentHeight * 0.9 {
                        if let lastLine = pageLines.popLast() {
                            remainingLines.insert(lastLine, at: 0)
                        }
                    }
                    
                    // Crear la página actual
                    let pageContent = pageLines.map { "<p>\($0)</p>" }.joined(separator: "\n")
                    if !pageContent.isEmpty {
                        pages.append(pageContent)
                    }
                }
            } else {
                // Si el bloque cabe en la página actual
                if currentHeight + blockHeight <= contentHeight {
                    currentPage += block
                    currentHeight += blockHeight
                } else {
                    // Si el bloque no cabe y la página actual está casi llena, mover todo el bloque a la siguiente página
                    if currentHeight > contentHeight * 0.9 {
                        if !currentPage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            pages.append(currentPage)
                        }
                        currentPage = block
                        currentHeight = blockHeight
                    } else {
                        // Si la página actual no está muy llena, dividir el bloque
                        let lines = splitTextIntoLines(text, charsPerLine: charsPerLine)
                        var remainingLines = lines
                        
                        // Llenar la página actual
                        while !remainingLines.isEmpty && currentHeight + lineHeightPx <= contentHeight {
                            let line = remainingLines.removeFirst()
                            currentPage += "<p>\(line)</p>\n"
                            currentHeight += lineHeightPx
                        }
                        
                        // Mover las líneas restantes a la siguiente página
                        if !remainingLines.isEmpty {
                            pages.append(currentPage)
                            currentPage = remainingLines.map { "<p>\($0)</p>" }.joined(separator: "\n")
                            currentHeight = CGFloat(remainingLines.count) * lineHeightPx
                        }
                    }
                }
            }
        }
        
        // Agregar la última página si tiene contenido
        if !currentPage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pages.append(currentPage)
        }
        
        return pages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func estimateLines(for text: String, charsPerLine: Int) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var lines = 0
        var currentLineChars = 0
        for word in words {
            if currentLineChars + word.count + 1 > charsPerLine {
                lines += 1
                currentLineChars = word.count
            } else {
                currentLineChars += word.count + 1
            }
        }
        if currentLineChars > 0 { lines += 1 }
        return max(1, lines)
    }
    
    private func splitTextIntoLines(_ text: String, charsPerLine: Int) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            if currentLine.count + word.count + 1 > charsPerLine {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            } else {
                if !currentLine.isEmpty {
                    currentLine += " "
                }
                currentLine += word
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
}

// Función para calcular las posiciones y páginas para un recurso HTML
func calculatePositions(for resource: EPUBResource, 
                       spine: EPUBSpine,
                       totalBytes: Int) -> EPUBPagedResource? {
    guard let data = resource.data,
          let content = String(data: data, encoding: .utf8) else {
        return nil
    }
    
    // Configuración de paginación
    let pageWidth: CGFloat = UIScreen.main.bounds.width
    let pageHeight: CGFloat = UIScreen.main.bounds.height
    let horizontalMargin: CGFloat = 40
    let verticalMargin: CGFloat = 40
    let fontSize: CGFloat = 16 // Tamaño de fuente base
    let lineHeight: CGFloat = 1.5
    
    // Crear el paginador inteligente
    let paginator = SmartPagination(
        content: content,
        fontSize: fontSize,
        lineHeight: lineHeight,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        horizontalMargin: horizontalMargin,
        verticalMargin: verticalMargin
    )
    
    // Calcular las páginas
    let pages = paginator.calculatePages()
    
    // Crear las posiciones
    var positions: [EPUBPosition] = []
    for (index, _) in pages.enumerated() {
        let progression = Double(index) / Double(pages.count - 1)
        let totalProgression = Double(resource.data?.count ?? 0) / Double(totalBytes)
        
        positions.append(EPUBPosition(
            resourceId: resource.resourceId,
            progression: progression,
            totalProgression: totalProgression,
            pageIndex: index,
            totalPages: pages.count
        ))
    }
    
    // Determinar si es RTL o vertical
    let isRTL = spine.isRightToLeft
    let isVertical = content.contains("writing-mode: vertical")
    
    return EPUBPagedResource(
        resourceId: resource.resourceId,
        totalPages: pages.count,
        positions: positions,
        isRTL: isRTL,
        isVertical: isVertical
    )
} 