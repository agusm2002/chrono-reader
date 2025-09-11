import SwiftUI
import WebKit

struct EPUBContentView: UIViewRepresentable {
    let html: String
    let baseURL: URL
    @Environment(\.colorScheme) var colorScheme
    
    // Agregar parámetros para el tema personalizado
    var theme: EPUBBasicReaderView.ReaderTheme = .system
    var systemColorScheme: ColorScheme = .light // Color del sistema para cuando theme es .system
    var font: EPUBSettingsPanel.FontOption = .original
    var isBoldText: Bool = false
    var fontSize: Double = 1.0 // Factor de escala para el tamaño de fuente (1.0 = 100%)
    
    // Parámetros de accesibilidad
    var lineHeight: Double = 1.2
    var letterSpacing: Double = 0.0
    var wordSpacing: Double = 0.0
    var textMargins: Double = 0.0
    
    // Índice de página para búsqueda
    var pageIndex: Int = 0
    
    // Determinar el modo actual (claro u oscuro) basado en el tema seleccionado
    private var effectiveColorScheme: ColorScheme {
        switch theme {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        
        // Guardar referencia al WebView para poder acceder a él desde las notificaciones
        context.coordinator.webView = webView
        
        // Determinar el color del texto según el tema efectivo
        let isDarkMode = effectiveColorScheme == .dark
        let textColor = isDarkMode ? "#FFFFFF" : "#333333"
        let linkColor = isDarkMode ? "#4DA3FF" : "#0066CC"
        
        // Preparar estilos de fuente y accesibilidad
        var fontFamilyCSS = ""
        var fontWeightCSS = isBoldText ? "bold" : "normal"
        
        if let fontName = font.fontName {
            fontFamilyCSS = "'" + fontName + "', -apple-system, BlinkMacSystemFont, sans-serif"
        }
        
        // Calcular el margen en pixels basado en el porcentaje
        let marginPercentage = Int(textMargins * 100)
        let marginPixels = marginPercentage > 0 ? "\(marginPercentage)px" : "0"
        
        // Configuración base de estilos para el tema y accesibilidad
        let themeCSS = """
            body, p, div, span, h1, h2, h3, h4, h5, h6, li, td, th {
                color: \(textColor);
                \(fontFamilyCSS.isEmpty ? "" : "font-family: \(fontFamilyCSS) !important;")
                font-weight: \(fontWeightCSS) !important;
                line-height: \(String(format: "%.2f", lineHeight)) !important;
                letter-spacing: \(String(format: "%.2fem", letterSpacing)) !important;
                word-spacing: \(String(format: "%.2fem", wordSpacing)) !important;
                font-size: \(String(format: "%.2f", fontSize))em !important;
            }
            body {
                background-color: transparent;
                margin-left: \(marginPixels);
                margin-right: \(marginPixels);
            }
            a {
                color: \(linkColor);
            }
        """
        
        // Envolver el HTML original con nuestro CSS mínimo
        let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style id="epub-custom-style">
                    \(themeCSS)
                </style>
                <script>
                    document.addEventListener('DOMContentLoaded', function() {
                        // Aplicar márgenes al contenedor principal si existe
                        var content = document.querySelector('body > div') || document.body;
                        content.style.marginLeft = '\(marginPixels)';
                        content.style.marginRight = '\(marginPixels)';
                    });
                </script>
            </head>
            <body>
                \(html)
            </body>
            </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: baseURL)
        
        // Actualizar el coordinador con los valores iniciales
        context.coordinator.lastEffectiveScheme = effectiveColorScheme
        context.coordinator.lastFont = font
        context.coordinator.lastBoldText = isBoldText
        context.coordinator.lastFontSize = fontSize
        context.coordinator.lastLineHeight = lineHeight
        context.coordinator.lastLetterSpacing = letterSpacing
        context.coordinator.lastWordSpacing = wordSpacing
        context.coordinator.lastTextMargins = textMargins
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Actualizar el contenido si cambia el tema o la fuente
        let currentEffectiveScheme = effectiveColorScheme
        let currentFont = font
        let currentBoldText = isBoldText
        let currentFontSize = fontSize
        let currentLineHeight = lineHeight
        let currentLetterSpacing = letterSpacing
        let currentWordSpacing = wordSpacing
        let currentTextMargins = textMargins
        
        if currentEffectiveScheme != context.coordinator.lastEffectiveScheme || 
           currentFont != context.coordinator.lastFont ||
           currentBoldText != context.coordinator.lastBoldText ||
           currentFontSize != context.coordinator.lastFontSize ||
           currentLineHeight != context.coordinator.lastLineHeight ||
           currentLetterSpacing != context.coordinator.lastLetterSpacing ||
           currentWordSpacing != context.coordinator.lastWordSpacing ||
           currentTextMargins != context.coordinator.lastTextMargins {
            
            // Actualizar coordinador
            context.coordinator.lastEffectiveScheme = currentEffectiveScheme
            context.coordinator.lastFont = currentFont
            context.coordinator.lastBoldText = currentBoldText
            context.coordinator.lastFontSize = currentFontSize
            context.coordinator.lastLineHeight = currentLineHeight
            context.coordinator.lastLetterSpacing = currentLetterSpacing
            context.coordinator.lastWordSpacing = currentWordSpacing
            context.coordinator.lastTextMargins = currentTextMargins
            
            // Determinar el color del texto según el tema efectivo
            let isDarkMode = currentEffectiveScheme == .dark
            let textColor = isDarkMode ? "#FFFFFF" : "#333333"
            let linkColor = isDarkMode ? "#4DA3FF" : "#0066CC"
            
            // Simplificar el script de JavaScript
            var fontFamilyCSS = ""
            var fontWeightCSS = currentBoldText ? "bold" : "normal"
            
            if let fontName = currentFont.fontName {
                fontFamilyCSS = "'" + fontName + "', -apple-system, BlinkMacSystemFont, sans-serif"
            }
            
            // Calcular el margen en pixels basado en el porcentaje
            let marginPercentage = Int(currentTextMargins * 100)
            let marginPixels = marginPercentage > 0 ? "\(marginPercentage)px" : "0"
            
            // Construir un CSS con opciones de accesibilidad
            let cssToApply = """
            body, p, div, span, h1, h2, h3, h4, h5, h6, li, td, th {
                color: \(textColor);
                \(fontFamilyCSS.isEmpty ? "" : "font-family: \(fontFamilyCSS) !important;")
                font-weight: \(fontWeightCSS) !important;
                line-height: \(String(format: "%.2f", currentLineHeight)) !important;
                letter-spacing: \(String(format: "%.2fem", currentLetterSpacing)) !important;
                word-spacing: \(String(format: "%.2fem", currentWordSpacing)) !important;
                font-size: \(String(format: "%.2f", currentFontSize))em !important;
            }
            body {
                background-color: transparent;
                margin-left: \(marginPixels);
                margin-right: \(marginPixels);
            }
            a {
                color: \(linkColor);
            }
            """
            
            // JavaScript simple para aplicar estilos
            let js = """
            (function() {
                // Crear estilo
                var style = document.getElementById('epub-custom-style');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'epub-custom-style';
                    document.head.appendChild(style);
                }
                
                // Aplicar CSS
                style.textContent = `\(cssToApply)`;
                
                // Aplicar márgenes al contenedor principal si existe
                var content = document.querySelector('body > div') || document.body;
                content.style.marginLeft = '\(marginPixels)';
                content.style.marginRight = '\(marginPixels)';
                
                // Aplicar fuente y negrita a todos los elementos de texto
                var allTextElements = document.querySelectorAll('p, div, span, h1, h2, h3, h4, h5, h6, li, td, th');
                allTextElements.forEach(function(el) {
                    \(fontFamilyCSS.isEmpty ? "" : "el.style.fontFamily = '\(fontFamilyCSS)';")
                    el.style.fontWeight = '\(fontWeightCSS)';
                    el.style.lineHeight = '\(String(format: "%.2f", currentLineHeight))';
                    el.style.letterSpacing = '\(String(format: "%.2fem", currentLetterSpacing))';
                    el.style.wordSpacing = '\(String(format: "%.2fem", currentWordSpacing))';
                    el.style.fontSize = '\(String(format: "%.2f", currentFontSize))em';
                });
            })();
            """
            
            // Ejecutar el script de JavaScript
            uiView.evaluateJavaScript(js) { (result, error) in
                if let error = error {
                    print("Error al aplicar estilos: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EPUBContentView
        var lastEffectiveScheme: ColorScheme
        var lastFont: EPUBSettingsPanel.FontOption
        var lastBoldText: Bool
        var lastFontSize: Double
        var lastLineHeight: Double
        var lastLetterSpacing: Double
        var lastWordSpacing: Double
        var lastTextMargins: Double
        var webView: WKWebView?
        var notificationObservers: [NSObjectProtocol] = []
        var pendingSearchHighlight: (position: Int, length: Int)?
        
        init(_ parent: EPUBContentView) {
            self.parent = parent
            self.lastEffectiveScheme = parent.effectiveColorScheme
            self.lastFont = parent.font
            self.lastBoldText = parent.isBoldText
            self.lastFontSize = parent.fontSize
            self.lastLineHeight = parent.lineHeight
            self.lastLetterSpacing = parent.letterSpacing
            self.lastWordSpacing = parent.wordSpacing
            self.lastTextMargins = parent.textMargins
            
            super.init()
            
            // Registrar para recibir notificaciones de búsqueda
            let searchObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("EPUBHighlightSearchResult"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let pageIndex = userInfo["pageIndex"] as? Int,
                      let position = userInfo["position"] as? Int,
                      let length = userInfo["length"] as? Int,
                      pageIndex == self.parent.pageIndex else {
                    return
                }
                
                // Si el WebView ya está disponible, ejecutar el resaltado inmediatamente
                if let webView = self.webView {
                    // Verificar si el WebView ha terminado de cargar
                    webView.evaluateJavaScript("document.readyState") { (result, error) in
                        if let readyState = result as? String, readyState == "complete" {
                            // Si está listo, resaltar inmediatamente
                            self.highlightAndScrollToText(webView: webView, position: position, length: length)
                        } else {
                            // Si no está listo, guardar para resaltar después
                            self.pendingSearchHighlight = (position, length)
                        }
                    }
                } else {
                    // Si el WebView aún no está disponible, guardar para resaltar después
                    self.pendingSearchHighlight = (position, length)
                }
            }
            
            // Registrar para recibir notificaciones de cambio de página
            let pageChangedObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("EPUBPageChanged"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let pageIndex = userInfo["pageIndex"] as? Int,
                      pageIndex == self.parent.pageIndex else {
                    return
                }
                
                // La página ha cambiado y es esta página
                // Notificar que esta página está lista
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(
                        name: Notification.Name("EPUBPageLoaded"),
                        object: nil,
                        userInfo: ["pageIndex": pageIndex]
                    )
                }
            }
            
            // Guardar los observadores para limpiarlos después
            notificationObservers.append(searchObserver)
            notificationObservers.append(pageChangedObserver)
        }
        
        deinit {
            // Eliminar todos los observadores cuando se destruye el coordinador
            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        // Implementar el delegado de navegación para detectar cuando el WebView termina de cargar
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // El WebView ha terminado de cargar
            print("WebView cargado para página \(parent.pageIndex)")
            
            // Notificar que la página está lista
            NotificationCenter.default.post(
                name: Notification.Name("EPUBPageLoaded"),
                object: nil,
                userInfo: ["pageIndex": parent.pageIndex]
            )
            
            // Si hay un resaltado pendiente, ejecutarlo ahora
            if let highlight = pendingSearchHighlight {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.highlightAndScrollToText(webView: webView, position: highlight.position, length: highlight.length)
                    self.pendingSearchHighlight = nil
                }
            }
        }
        
        // Función para resaltar y hacer scroll al texto encontrado
        func highlightAndScrollToText(webView: WKWebView, position: Int, length: Int) {
            // Primero, vamos a obtener el texto que estamos buscando para hacer una búsqueda más precisa
            let getTextScript = """
            (function() {
                // Extraer todo el texto del documento
                const allText = document.body.innerText;
                // Obtener el texto en la posición aproximada
                const startPos = Math.max(0, \(position) - 5);
                const endPos = Math.min(allText.length, \(position) + \(length) + 5);
                return allText.substring(startPos, endPos);
            })();
            """
            
            webView.evaluateJavaScript(getTextScript) { (textResult, error) in
                if let error = error {
                    print("Error al obtener texto: \(error.localizedDescription)")
                    return
                }
                
                guard let searchText = textResult as? String else {
                    print("No se pudo obtener el texto para buscar")
                    return
                }
                
                // Ahora usamos el texto encontrado para hacer una búsqueda más precisa
                // Eliminamos espacios y caracteres especiales para hacer la búsqueda más robusta
                let cleanSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                               .replacingOccurrences(of: "\\s+", with: "\\\\s+", options: .regularExpression)
                
                if cleanSearchText.isEmpty {
                    print("Texto de búsqueda vacío después de limpieza")
                    return
                }
                
                // Script mejorado que usa la búsqueda de texto en lugar de posiciones
                let script = """
                (function() {
                    // Limpiar resaltados previos
                    const oldHighlights = document.querySelectorAll('span.search-highlight');
                    oldHighlights.forEach(h => {
                        const parent = h.parentNode;
                        while (h.firstChild) {
                            parent.insertBefore(h.firstChild, h);
                        }
                        parent.removeChild(h);
                    });
                    
                    // Función para buscar y resaltar texto
                    function findAndHighlightText() {
                        // Usamos un enfoque más directo: buscar en todo el texto del documento
                        const allText = document.body.innerHTML;
                        const searchText = \(cleanSearchText.isEmpty ? "\"\"" : "\"\(cleanSearchText)\"");
                        
                        // Primero intentamos con una búsqueda exacta
                        let foundPos = -1;
                        
                        // Intentar encontrar el texto de forma aproximada si es necesario
                        if (searchText && searchText.length > 3) {
                            // Usar una expresión regular para encontrar el texto de manera más flexible
                            try {
                                const escapedSearchText = searchText.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
                                const regex = new RegExp(escapedSearchText, 'i');
                                const match = regex.exec(allText);
                                if (match) {
                                    foundPos = match.index;
                                }
                            } catch (e) {
                                console.error('Error en regex:', e);
                            }
                        }
                        
                        if (foundPos === -1) {
                            // Si no encontramos el texto, intentamos una búsqueda más amplia
                            // Buscar todos los elementos de texto y hacer scroll al que esté más cerca de la posición
                            const textNodes = [];
                            const walker = document.createTreeWalker(
                                document.body,
                                NodeFilter.SHOW_TEXT,
                                null,
                                false
                            );
                            
                            let node;
                            let totalLength = 0;
                            let bestNode = null;
                            let bestDistance = Number.MAX_VALUE;
                            let targetPosition = \(position);
                            
                            while (node = walker.nextNode()) {
                                const nodeLength = node.textContent.length;
                                const distance = Math.abs(totalLength - targetPosition);
                                
                                if (distance < bestDistance) {
                                    bestDistance = distance;
                                    bestNode = node;
                                }
                                
                                totalLength += nodeLength;
                            }
                            
                            if (bestNode) {
                                // Resaltar este nodo y hacer scroll
                                const range = document.createRange();
                                range.selectNode(bestNode);
                                
                                const span = document.createElement('span');
                                span.className = 'search-highlight';
                                span.style.backgroundColor = '#FFFF00';
                                span.style.color = '#000000';
                                span.style.padding = '2px';
                                span.style.borderRadius = '3px';
                                span.style.transition = 'background-color 2s ease-out';
                                
                                try {
                                    range.surroundContents(span);
                                    span.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                    
                                    // Animar el resaltado
                                    setTimeout(() => {
                                        span.style.backgroundColor = 'transparent';
                                    }, 3000);
                                    
                                    return true;
                                } catch (e) {
                                    console.error('Error al resaltar:', e);
                                }
                            }
                            
                            return false;
                        } else {
                            // Si encontramos el texto, lo resaltamos
                            const tempDiv = document.createElement('div');
                            tempDiv.innerHTML = allText;
                            
                            // Crear un rango que abarque todo el documento
                            const range = document.createRange();
                            range.setStart(document.body, 0);
                            range.setEnd(document.body, document.body.childNodes.length);
                            
                            // Reemplazar el texto encontrado con una versión resaltada
                            const highlightedHTML = allText.substring(0, foundPos) + 
                                '<span class="search-highlight" style="background-color: #FFFF00; color: #000000; padding: 2px; border-radius: 3px; transition: background-color 2s ease-out;">' + 
                                allText.substring(foundPos, foundPos + searchText.length) + 
                                '</span>' + 
                                allText.substring(foundPos + searchText.length);
                            
                            // Encontrar el elemento que contiene el texto
                            const elements = document.querySelectorAll('*');
                            let targetElement = null;
                            let currentPos = 0;
                            
                            for (let i = 0; i < elements.length; i++) {
                                const el = elements[i];
                                if (el.innerText) {
                                    const elLength = el.innerText.length;
                                    if (currentPos <= foundPos && foundPos < currentPos + elLength) {
                                        targetElement = el;
                                        break;
                                    }
                                    currentPos += elLength;
                                }
                            }
                            
                            if (targetElement) {
                                // Resaltar el texto dentro del elemento
                                const elText = targetElement.innerHTML;
                                const elPos = foundPos - currentPos;
                                
                                if (elPos >= 0 && elPos < elText.length) {
                                    targetElement.innerHTML = 
                                        elText.substring(0, elPos) + 
                                        '<span class="search-highlight" style="background-color: #FFFF00; color: #000000; padding: 2px; border-radius: 3px; transition: background-color 2s ease-out;">' + 
                                        elText.substring(elPos, elPos + searchText.length) + 
                                        '</span>' + 
                                        elText.substring(elPos + searchText.length);
                                    
                                    // Hacer scroll al elemento resaltado
                                    const highlight = document.querySelector('.search-highlight');
                                    if (highlight) {
                                        highlight.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                        
                                        // Animar el resaltado
                                        setTimeout(() => {
                                            highlight.style.backgroundColor = 'transparent';
                                        }, 3000);
                                        
                                        return true;
                                    }
                                }
                            }
                            
                            // Si no pudimos resaltar el texto específico, al menos hacemos scroll a la posición aproximada
                            window.scrollTo(0, document.body.scrollHeight * (\(position) / document.body.innerText.length));
                            return false;
                        }
                    }
                    
                    // Ejecutar la búsqueda y resaltado
                    return findAndHighlightText();
                })();
                """
                
                webView.evaluateJavaScript(script) { (result, error) in
                    if let error = error {
                        print("Error al resaltar texto: \(error.localizedDescription)")
                        
                        // Plan B: Si falla el resaltado, al menos hacemos scroll a una posición aproximada
                        let fallbackScript = """
                        (function() {
                            // Calcular la posición relativa en el documento
                            const totalLength = document.body.innerText.length;
                            const relativePos = \(position) / totalLength;
                            
                            // Hacer scroll a una posición aproximada
                            window.scrollTo(0, document.body.scrollHeight * relativePos);
                            return true;
                        })();
                        """
                        
                        webView.evaluateJavaScript(fallbackScript) { (_, _) in }
                    }
                }
            }
        }
    }
} 