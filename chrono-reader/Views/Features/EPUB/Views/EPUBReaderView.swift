import SwiftUI

struct EPUBBasicReaderView: View {
    let document: EPUBBook
    @State private var currentPage = 0
    @State private var pageContent: [String] = []
    @State private var isLoading = true
    @State private var baseURL: URL?
    @State private var showHUD: Bool = true
    @State private var showTOC: Bool = false
    @State private var showOptionsMenu: Bool = false
    @State private var showSettings: Bool = false
    @State private var showOption1: Bool = false
    @State private var showOption2: Bool = false
    @State private var showSearchPanel: Bool = false
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [(pageIndex: Int, text: String, percentage: Double, matchPosition: Int, matchLength: Int)] = []
    @State private var selectedTheme: ReaderTheme = .system
    @State private var selectedFont: EPUBSettingsPanel.FontOption = .original
    @State private var isBoldTextEnabled: Bool = false
    @State private var showFontSelector: Bool = false
    @State private var fontSize: Double = 1.0 // Tamaño de fuente (1.0 = base)
    
    // Opciones de accesibilidad y disposición del texto
    @State private var lineHeight: Double = 1.2 // Interlineado (valor por defecto)
    @State private var letterSpacing: Double = 0.0 // Espaciado entre caracteres (%)
    @State private var wordSpacing: Double = 0.0 // Espaciado entre palabras (%)
    @State private var textMargins: Double = 0.0 // Márgenes (%)
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // Configuración de lectura
    private let pageWidth: CGFloat = UIScreen.main.bounds.width
    private let pageHeight: CGFloat = UIScreen.main.bounds.height
    private let pageMargin: CGFloat = 20
    
    // Enum para los temas del lector (tiene que estar aquí también para acceso global)
    enum ReaderTheme: String, CaseIterable, Identifiable {
        case system = "Sistema"
        case light = "Claro"
        case dark = "Oscuro"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max"
            case .dark: return "moon"
            }
        }
    }
    
    // Estilo de blur adaptativo según el tema seleccionado
    private var adaptiveBlurStyle: UIBlurEffect.Style {
        switch selectedTheme {
        case .system:
        return colorScheme == .dark ? .systemMaterialDark : .systemMaterialLight
        case .light:
            return .systemMaterialLight
        case .dark:
            return .systemMaterialDark
        }
    }
    
    // Color de fondo según el tema seleccionado
    private var backgroundColor: Color {
        switch selectedTheme {
        case .system:
            return colorScheme == .dark ? Color.black : Color.white
        case .light:
            return Color.white
        case .dark:
            return Color.black
        }
    }
    
    var body: some View {
        ZStack {
            // Fondo adaptado al tema
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            GeometryReader { geometry in
                if isLoading {
                    ProgressView("Cargando...")
                } else if let baseURL = baseURL {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pageContent.count, id: \.self) { index in
                            EPUBBasicPageView(
                                content: pageContent[index],
                                baseURL: baseURL,
                                theme: selectedTheme,
                                systemColorScheme: colorScheme,
                                font: selectedFont,
                                isBoldText: isBoldTextEnabled,
                                fontSize: fontSize,
                                lineHeight: lineHeight,
                                letterSpacing: letterSpacing,
                                wordSpacing: wordSpacing,
                                textMargins: textMargins,
                                pageIndex: index
                            )
                                .frame(width: pageWidth, height: pageHeight)
                                .tag(index)
                                .id("\(index)-\(selectedTheme)-\(selectedFont.id)-\(isBoldTextEnabled)-\(fontSize)-\(lineHeight)-\(letterSpacing)-\(wordSpacing)-\(textMargins)")
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .environment(\.layoutDirection, document.spine.isRightToLeft ? .rightToLeft : .leftToRight)
                } else {
                    Text("Error: No se pudo determinar la ubicación base del libro")
                        .foregroundColor(.red)
                }
            }
            
            // HUD con estilo moderno similar al reproductor de audio
            if showHUD {
                VStack {
                    HStack {
                        // Botón de regresar
                        Button(action: {
                            // Volver al home
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(BlurView(style: adaptiveBlurStyle))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        
                        Spacer()
                        
                        // Botón de configuración
                        Button(action: {
                            withAnimation(.spring()) {
                                showSettings = true
                            }
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(BlurView(style: adaptiveBlurStyle))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Barra de botones inferior
                    HStack(spacing: 20) {
                        Spacer()
                        
                        // Botón de opciones
                        Button(action: {
                            withAnimation(.spring()) {
                                showOptionsMenu.toggle()
                                if showOptionsMenu {
                                    // Si estamos abriendo el menú, activamos la animación y aseguramos que el HUD esté visible
                                    animateOptionsIn()
                                    showHUD = true
                                } else {
                                    // Si estamos cerrando el menú, reseteamos los estados
                                    resetOptionStates()
                                }
                            }
                        }) {
                            Image(systemName: showOptionsMenu ? "chevron.left" : "book.and.wrench")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(BlurView(style: adaptiveBlurStyle))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            
            // Menú flotante centrado (estilo moderno y elegante)
            if showTOC {
                GeometryReader { proxy in
                    ZStack {
                        // Fondo semi-transparente para cerrar el menú
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    showTOC = false
                                }
                            }
                        
                        EPUBTOCPanel(
                            document: document,
                            proxy: proxy,
                            showTOC: $showTOC,
                            currentPage: $currentPage,
                            navigateToSection: navigateToSection,
                            theme: selectedTheme
                        )
                    }
                    .zIndex(2)
                }
            }
            
            // Menú de opciones estilo Apple Books
            if showOptionsMenu {
                VStack {
                    Spacer()
                    
                    // Panel de opciones
                    VStack(spacing: 8) {
                        // Opción: Contenido
                        if showOption1 {
                            Button(action: {
                                withAnimation(.spring()) {
                                    showOptionsMenu = false
                                    showTOC = true
                                    resetOptionStates()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .frame(width: 24)
                                    Text("Contents")
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .foregroundColor(.primary)
                                .background(BlurView(style: adaptiveBlurStyle))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Opción: Buscar
                        if showOption2 {
                            Button(action: {
                                // Abrir panel de búsqueda
                                withAnimation(.spring()) {
                                    showOptionsMenu = false
                                    showSearchPanel = true
                                    resetOptionStates()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .frame(width: 24)
                                    Text("Search Book")
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .foregroundColor(.primary)
                                .background(BlurView(style: adaptiveBlurStyle))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .frame(width: 220)
                    .padding(.bottom, 80)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .zIndex(3)
                .background(
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showOptionsMenu = false
                                resetOptionStates()
                            }
                        }
                )
                .transition(.opacity)
            }
            
            // Panel de configuración lateral
            if showSettings {
                EPUBSettingsPanel(isPresented: $showSettings, 
                                  selectedTheme: $selectedTheme, 
                                  selectedFont: $selectedFont, 
                                  isBoldTextEnabled: $isBoldTextEnabled,
                                  fontSize: $fontSize,
                                  lineHeight: $lineHeight, 
                                  letterSpacing: $letterSpacing, 
                                  wordSpacing: $wordSpacing, 
                                  textMargins: $textMargins,
                                  currentPage: $currentPage)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(4)
            }
            
            // Panel de búsqueda
            if showSearchPanel {
                EPUBSearchPanel(
                    isPresented: $showSearchPanel,
                    searchText: $searchText,
                    isSearching: $isSearching,
                    searchResults: $searchResults,
                    currentPage: $currentPage,
                    totalPages: pageContent.count,
                    onSearch: performSearch,
                    theme: selectedTheme,
                    systemColorScheme: colorScheme,
                    onSelectResult: navigateToSearchResult
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            // Solo alternar los controles si el menú de opciones no está visible
            if !showOptionsMenu {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHUD.toggle()
                }
            }
        })
        .onAppear {
            loadContent()
        }
        // Observar cambios en el tema para recargar el contenido si es necesario
        .onChange(of: selectedTheme) { _ in
            // EPUBContentView maneja los cambios de tema internamente
            // Forzar actualización de la vista
            let currentIndex = currentPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    // Esto fuerza una recarga de la vista actual
                    self.currentPage = currentIndex
                }
            }
        }
        .onChange(of: selectedFont) { _ in
            // EPUBContentView maneja los cambios de fuente internamente
            // Forzar actualización de la vista
            let currentIndex = currentPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    // Esto fuerza una recarga de la vista actual
                    self.currentPage = currentIndex
                }
            }
        }
        .onChange(of: isBoldTextEnabled) { _ in
            // EPUBContentView maneja los cambios de negrita internamente
            // Forzar actualización de la vista
            let currentIndex = currentPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    // Esto fuerza una recarga de la vista actual
                    self.currentPage = currentIndex
                }
            }
        }
        .onChange(of: fontSize) { _ in
            // Forzar actualización de la vista
            let currentIndex = currentPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    // Esto fuerza una recarga de la vista actual
                    self.currentPage = currentIndex
                }
            }
        }
        // Los cambios en las opciones de accesibilidad se manejan a través del id en el ForEach
    }
    
    private func navigateToSection(_ tocReference: EPUBTocReference) {
        // Cerrar el panel TOC
            withAnimation(.spring()) {
                showTOC = false
        }
        
        // Buscar el recurso correspondiente a la referencia TOC
        let resourceID = tocReference.resourceId
        if let spineIndex = document.spine.spineReferences.firstIndex(where: { $0.resourceId == resourceID }) {
            // Navegar a la página correspondiente
            withAnimation {
                currentPage = spineIndex
            }
        }
    }
    
    private func loadContent() {
        // Determinar la URL base para el libro
        if let firstResource = document.resources.first?.value {
            // Crear la URL a partir del fullHref
            let fullPath = firstResource.fullHref
            let url = URL(fileURLWithPath: fullPath).deletingLastPathComponent()
            self.baseURL = url
            
            // Determinar el contenido a cargar
            let spine = document.spine
            var allContent: [String] = []
            
            for spineRef in spine.spineReferences {
                if let resource = document.resources[spineRef.resourceId],
                   let data = resource.data,
                   let content = String(data: data, encoding: .utf8) {
                    allContent.append(content)
                }
            }
            
            self.pageContent = allContent
            self.isLoading = false
        }
    }
    
    private func resetOptionStates() {
        showOption1 = false
        showOption2 = false
    }
    
    // Función para navegar a un resultado de búsqueda específico
    private func navigateToSearchResult(pageIndex: Int, position: Int, length: Int) {
        // Guardamos los datos del resultado para usarlos después de la navegación
        let searchData: [String: Any] = [
            "pageIndex": pageIndex,
            "position": position,
            "length": length
        ]
        
        // Verificamos si estamos en la misma página o necesitamos navegar
        if currentPage == pageIndex {
            // Si ya estamos en la página correcta, solo necesitamos resaltar
            NotificationCenter.default.post(
                name: Notification.Name("EPUBHighlightSearchResult"),
                object: nil,
                userInfo: searchData
            )
        } else {
            // Si necesitamos navegar a otra página, primero declaramos una variable para el observador
            var observerRef: NSObjectProtocol?
            
            // Función para manejar la notificación de cambio de página
            let handlePageChange = { (notification: Notification) in
                guard let notificationPageIndex = notification.userInfo?["pageIndex"] as? Int,
                      notificationPageIndex == pageIndex else {
                    return
                }
                
                // Eliminar el observador después de usarlo
                if let observer = observerRef {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                // Esperar a que la página se cargue completamente antes de resaltar
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    NotificationCenter.default.post(
                        name: Notification.Name("EPUBHighlightSearchResult"),
                        object: nil,
                        userInfo: searchData
                    )
                }
            }
            
            // Registramos el observador
            observerRef = NotificationCenter.default.addObserver(
                forName: Notification.Name("EPUBPageChanged"),
                object: nil,
                queue: .main,
                using: handlePageChange
            )
            
            // Ahora navegamos a la página correcta
            withAnimation {
                currentPage = pageIndex
            }
            
            // Emitimos una notificación de que la página ha cambiado
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: Notification.Name("EPUBPageChanged"),
                    object: nil,
                    userInfo: ["pageIndex": pageIndex]
                )
            }
        }
    }
    
    private func animateOptionsIn() {
        // Resetear estados
        showOption1 = false
        showOption2 = false
        
        // Animación escalonada
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
            showOption1 = true
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
            showOption2 = true
        }
    }
    
    // Función para realizar la búsqueda en el contenido del libro
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchResults = []
        
        // Buscar en cada página del contenido
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [(pageIndex: Int, text: String, percentage: Double, matchPosition: Int, matchLength: Int)] = []
            
            for (index, content) in self.pageContent.enumerated() {
                // Vamos a buscar directamente en el HTML para mantener las posiciones exactas
                // pero también extraeremos el texto plano para mostrar contexto legible
                let originalHTML = content
                
                // Crear una versión sin etiquetas para la búsqueda de texto
                let plainText = content.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
                                       .replacingOccurrences(of: "&nbsp;", with: " ")
                                       .replacingOccurrences(of: "&lt;", with: "<")
                                       .replacingOccurrences(of: "&gt;", with: ">")
                                       .replacingOccurrences(of: "&amp;", with: "&")
                
                // Buscar todas las ocurrencias (case insensitive)
                do {
                    let regex = try NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: self.searchText), options: [.caseInsensitive])
                    let nsString = plainText as NSString
                    let matches = regex.matches(in: plainText, options: [], range: NSRange(location: 0, length: nsString.length))
                    
                    for match in matches {
                        let range = match.range
                        let matchText = nsString.substring(with: range)
                        
                        // Obtener contexto alrededor de la coincidencia
                        let startContext = max(0, range.location - 40)
                        let lengthContext = min(nsString.length - startContext, range.location - startContext + range.length + 40)
                        let contextRange = NSRange(location: startContext, length: lengthContext)
                        var contextText = nsString.substring(with: contextRange)
                        
                        // Resaltar el texto encontrado en el contexto
                        let matchStartInContext = range.location - startContext
                        let matchEndInContext = matchStartInContext + range.length
                        
                        if matchStartInContext >= 0 && matchEndInContext <= contextText.count {
                            let prefix = String(contextText.prefix(matchStartInContext))
                            let match = String(contextText.dropFirst(matchStartInContext).prefix(range.length))
                            let suffix = String(contextText.dropFirst(matchEndInContext))
                            contextText = "\(prefix)...\(match)...\(suffix)"
                        }
                        
                        // Calcular el porcentaje de progreso
                        let percentage = Double(index) / Double(self.pageContent.count) * 100
                        
                        // Guardar la posición exacta del texto encontrado en el contenido original
                        let matchPosition = range.location
                        let matchLength = range.length
                        
                        // Guardar el texto original para búsqueda exacta
                        let searchTerm = matchText
                        
                        results.append((index, contextText, percentage, matchPosition, matchLength))
                    }
                } catch {
                    print("Error en la búsqueda: \(error)")
                }
            }
            
            // Actualizar resultados en el hilo principal
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}

// Extensión para esquinas redondeadas selectivas
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(EPUBRoundedCorner(radius: radius, corners: corners))
    }
}

struct EPUBRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct EPUBBasicPageView: View {
    let content: String
    let baseURL: URL
    let theme: EPUBBasicReaderView.ReaderTheme
    let systemColorScheme: ColorScheme
    let font: EPUBSettingsPanel.FontOption
    let isBoldText: Bool
    let fontSize: Double
    let lineHeight: Double
    let letterSpacing: Double
    let wordSpacing: Double
    let textMargins: Double
    let pageIndex: Int // Recibir el índice directamente
    
    var body: some View {
        EPUBContentView(
            html: content,
            baseURL: baseURL,
            theme: theme,
            systemColorScheme: systemColorScheme,
            font: font,
            isBoldText: isBoldText,
            fontSize: fontSize,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
            textMargins: textMargins,
            pageIndex: pageIndex
        )
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Notificar que esta página se ha cargado
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(
                    name: Notification.Name("EPUBPageLoaded"),
                    object: nil,
                    userInfo: ["pageIndex": pageIndex]
                )
            }
        }
    }
}

// Vista previa para desarrollo
struct EPUBBasicReaderView_Previews: PreviewProvider {
    static var previews: some View {
        // TODO: Implementar vista previa con datos de ejemplo
        Text("Vista previa no disponible")
    }
}

// BlurView para fondo borroso
import UIKit
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Panel de búsqueda para el lector EPUB
struct EPUBSearchPanel: View {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var searchResults: [(pageIndex: Int, text: String, percentage: Double, matchPosition: Int, matchLength: Int)]
    @Binding var currentPage: Int
    let totalPages: Int
    let onSearch: () -> Void
    let theme: EPUBBasicReaderView.ReaderTheme
    let systemColorScheme: ColorScheme
    let onSelectResult: (Int, Int, Int) -> Void
    
    @State private var searchFieldFocused: Bool = false
    
    // Estilo de blur adaptativo según el tema
    private var adaptiveBlurStyle: UIBlurEffect.Style {
        switch theme {
        case .system:
            return systemColorScheme == .dark ? .systemMaterialDark : .systemMaterialLight
        case .light:
            return .systemMaterialLight
        case .dark:
            return .systemMaterialDark
        }
    }
    
    // Color de fondo según el tema
    private var backgroundColor: Color {
        switch theme {
        case .system:
            return systemColorScheme == .dark ? Color.black.opacity(0.9) : Color.white.opacity(0.9)
        case .light:
            return Color.white.opacity(0.9)
        case .dark:
            return Color.black.opacity(0.9)
        }
    }
    
    var body: some View {
        ZStack {
            // Fondo semitransparente para cerrar el panel
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Panel de búsqueda
            VStack(spacing: 0) {
                // Encabezado
                HStack {
                    Text("Buscar")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // Campo de búsqueda
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Buscar en el libro", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            onSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Botón de búsqueda
                Button(action: {
                    onSearch()
                }) {
                    HStack {
                        Spacer()
                        Text("Buscar")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .disabled(searchText.isEmpty)
                .opacity(searchText.isEmpty ? 0.6 : 1.0)
                
                Divider()
                
                // Resultados de búsqueda
                if isSearching {
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Buscando...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(height: 200)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        Text("No se encontraron resultados")
                            .font(.headline)
                        Text("Intenta con otra palabra o frase")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        Spacer()
                    }
                    .frame(height: 200)
                } else if !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<searchResults.count, id: \.self) { index in
                                let result = searchResults[index]
                                Button(action: {
                                    // Usar la función de navegación avanzada
                                    onSelectResult(result.pageIndex, result.matchPosition, result.matchLength)
                                    
                                    // Cerrar el panel de búsqueda
                                    withAnimation(.spring()) {
                                        isPresented = false
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Página \(result.pageIndex + 1) de \(totalPages)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            Text(String(format: "%.1f%%", result.percentage))
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Text(result.text)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color.clear)
                                }
                                
                                if index < searchResults.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                } else {
                    // Estado inicial, sin búsqueda
                    VStack {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 12)
                        Text("Buscar en el libro")
                            .font(.headline)
                        Text("Escribe una palabra o frase para buscar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        Spacer()
                    }
                    .frame(height: 200)
                }
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.95, 400))
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }
}

// Subvista para el panel flotante TOC
struct EPUBTOCPanel: View {
    let document: EPUBBook
    let proxy: GeometryProxy
    @Binding var showTOC: Bool
    @Binding var currentPage: Int
    var navigateToSection: (EPUBTocReference) -> Void
    @Environment(\.colorScheme) var colorScheme
    var theme: EPUBBasicReaderView.ReaderTheme
    
    // Estilo de blur adaptativo según el tema
    private var adaptiveBlurStyle: UIBlurEffect.Style {
        switch theme {
        case .system:
        return colorScheme == .dark ? .systemMaterialDark : .systemMaterialLight
        case .light:
            return .systemMaterialLight
        case .dark:
            return .systemMaterialDark
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Encabezado del panel
            HStack {
                Text("Contenido")
                    .font(.title2).bold()
                    .foregroundColor(.primary)
                    .padding(.leading, 20)
                    .padding(.vertical, 18)
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        showTOC = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .background(BlurView(style: adaptiveBlurStyle))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            
            // Lista de contenido recursiva
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    tocList(document.tableOfContents)
                }
            }
            .padding(.bottom, 12)
        }
        .frame(width: min(proxy.size.width * 0.78, 380))
        .frame(height: proxy.size.height - 32) // Padding vertical de 16 arriba y abajo
        .background(BlurView(style: adaptiveBlurStyle))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 8)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .transition(.move(edge: .trailing))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // Función para mostrar la tabla de contenidos
    @ViewBuilder
    private func tocList(_ items: [EPUBTocReference], level: Int = 0) -> some View {
        ForEach(items) { tocItem in
            tocItemView(tocItem, level: level)
        }
    }
    
    // Vista para cada elemento de la tabla de contenidos
    private func tocItemView(_ tocItem: EPUBTocReference, level: Int) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                // Botón para el ítem actual
                Button(action: {
                    navigateToSection(tocItem)
                }) {
                    HStack {
                        Text(tocItem.title)
                            .foregroundColor(.primary)
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, CGFloat(level * 18) + 20)
                            .padding(.vertical, 14)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.0001))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                // Separador después de cada ítem (excepto el último, que se manejará en el nivel superior)
                Divider().background(Color.secondary.opacity(0.15))
                // Mostrar hijos si existen y no estamos demasiado profundos
                if !tocItem.children.isEmpty && level < 3 {
                    ForEach(tocItem.children) { childItem in
                        tocItemView(childItem, level: level + 1)
                    }
                }
            }
        )
    }
}

// Panel de configuración centrado estilo audiolibros/cómics
struct EPUBSettingsPanel: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedTheme: EPUBBasicReaderView.ReaderTheme
    @Binding var selectedFont: FontOption
    @Binding var isBoldTextEnabled: Bool
    @Binding var fontSize: Double
    
    // Bindings para opciones de accesibilidad
    @Binding var lineHeight: Double
    @Binding var letterSpacing: Double
    @Binding var wordSpacing: Double
    @Binding var textMargins: Double
    
    // Referencia a la página actual para poder forzar actualizaciones
    @Binding var currentPage: Int
    
    @State private var showFontSelector: Bool = false
    
    // Opciones de fuente disponibles
    enum FontOption: String, CaseIterable, Identifiable {
        case original = "Original"
        case athelas = "Athelas"
        case avenirNext = "Avenir Next"
        case charter = "Charter"
        case georgia = "Georgia"
        case iowan = "Iowan"
        case palatino = "Palatino"
        case proximaNova = "Proxima Nova"
        case seravek = "Seravek"
        case timesNewRoman = "Times New Roman"
        
        var id: String { self.rawValue }
        
        var fontName: String? {
            switch self {
            case .original:
                return nil // Usar la fuente original del EPUB
            case .athelas:
                return "Athelas"
            case .avenirNext:
                return "Avenir Next"
            case .charter:
                return "Charter"
            case .georgia:
                return "Georgia"
            case .iowan:
                return "Iowan Old Style"
            case .palatino:
                return "Palatino"
            case .proximaNova:
                return "Proxima Nova"
            case .seravek:
                return "Seravek"
            case .timesNewRoman:
                return "Times New Roman"
            }
        }
        
        var displayImage: String {
            switch self {
            case .original:
                return "doc.text"
            case .athelas, .palatino, .georgia, .timesNewRoman:
                return "textformat.alt" // Fuentes serif
            case .avenirNext, .seravek, .proximaNova:
                return "textformat.size" // Fuentes sans-serif
            case .charter, .iowan:
                return "textformat.abc" // Fuentes con personalidad
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Fondo semitransparente
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Panel centrado con bordes redondeados - versión compacta con transparencia
            VStack(spacing: 0) {
                // Encabezado
                HStack {
                    Text("Configuración")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Contenido en ScrollView para admitir más opciones
                ScrollView {
                    // Sección OPCIONES
                VStack(alignment: .leading, spacing: 16) {
                    Text("OPCIONES")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                        // Opción: Tema de lectura
                        VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 36, height: 36)
                            
                                    Image(systemName: selectedTheme.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                                    Text("Tema de lectura")
                                .font(.headline)
                            
                                    Text("Cambia entre tema del sistema, claro u oscuro")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Reemplazar el SegmentedPicker por una opción más visual
                            HStack(spacing: 16) {
                                // Opción Sistema
                                Button(action: { selectedTheme = .system }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedTheme == .system ? Color.blue.opacity(0.2) : Color.clear)
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "circle.lefthalf.filled")
                                                .font(.system(size: 24))
                                                .foregroundColor(selectedTheme == .system ? .blue : .primary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedTheme == .system ? Color.blue : Color.gray.opacity(0.5), lineWidth: 2)
                                        )
                                        
                                        Text("Sistema")
                                            .font(.caption)
                                            .foregroundColor(selectedTheme == .system ? .blue : .primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Opción Claro
                                Button(action: { selectedTheme = .light }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedTheme == .light ? Color.blue.opacity(0.2) : Color.clear)
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "sun.max")
                                                .font(.system(size: 24))
                                                .foregroundColor(selectedTheme == .light ? .blue : .primary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedTheme == .light ? Color.blue : Color.gray.opacity(0.5), lineWidth: 2)
                                        )
                                        
                                        Text("Claro")
                                            .font(.caption)
                                            .foregroundColor(selectedTheme == .light ? .blue : .primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Opción Oscuro
                                Button(action: { selectedTheme = .dark }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedTheme == .dark ? Color.blue.opacity(0.2) : Color.clear)
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: "moon")
                                                .font(.system(size: 24))
                                                .foregroundColor(selectedTheme == .dark ? .blue : .primary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedTheme == .dark ? Color.blue : Color.gray.opacity(0.5), lineWidth: 2)
                                        )
                                        
                                        Text("Oscuro")
                                            .font(.caption)
                                            .foregroundColor(selectedTheme == .dark ? .blue : .primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    }
                    
                    // NUEVA SECCIÓN: TEXTO
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TEXTO")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        // Opción: Tamaño de fuente
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .frame(width: 36, height: 36)
                                    
                                    Text("Aa")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tamaño de fuente")
                                        .font(.headline)
                                    
                                    Text("Ajusta el tamaño del texto")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(String(format: "%.2f", fontSize))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            
                            // Control de tamaño con botones - y +
                            HStack(spacing: 12) {
                                Button(action: {
                                    // Reducir tamaño (mínimo 0.7)
                                    withAnimation {
                                        fontSize = max(0.7, fontSize - 0.01)
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                                
                                // Slider para tamaño de fuente
                                Slider(value: $fontSize, in: 0.7...1.5, step: 0.01)
                                    .accentColor(.blue)
                                
                                Button(action: {
                                    // Aumentar tamaño (máximo 1.5)
                                    withAnimation {
                                        fontSize = min(1.5, fontSize + 0.01)
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Botón para restaurar al tamaño predeterminado
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        fontSize = 1.0 // Restaurar al valor predeterminado
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 12))
                                        Text("Restaurar a 1.00")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Opción: Fuente de texto - Mostrar opciones horizontalmente
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "textformat")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fuente")
                                        .font(.headline)
                                    
                                    Text("Cambia el tipo de letra del texto")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            
                            // Selector de fuentes horizontal simple
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    // Mostrar todas las fuentes disponibles
                                    ForEach(FontOption.allCases) { fontOption in
                                        fontButton(for: fontOption)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Opción: Texto en negrita
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "bold")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Texto en negrita")
                                        .font(.headline)
                                    
                                    Text("Resalta el texto para mejor legibilidad")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $isBoldTextEnabled)
                                    .labelsHidden()
                                    .onChange(of: isBoldTextEnabled) { newValue in
                                        // Forzar actualización del texto en negrita
                                        // Este código adicional garantiza que el cambio se aplique inmediatamente
                                        withAnimation {
                                            // La animación mejora la experiencia del usuario
                                            isBoldTextEnabled = newValue
                                            
                                            // Forzar actualización de la vista
                                            let currentIndex = currentPage
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation {
                                                    // Esto fuerza una recarga de la vista actual
                                                    currentPage = currentIndex
                                                }
                                            }
                                        }
                                    }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // NUEVA SECCIÓN: ACCESIBILIDAD
                        VStack(alignment: .leading, spacing: 16) {
                            // Cabecera de sección
                            HStack {
                                Text("ACCESIBILIDAD")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Restaurar valores predeterminados
                                    lineHeight = 1.2
                                    letterSpacing = 0.0
                                    wordSpacing = 0.0
                                    textMargins = 0.0
                                    fontSize = 1.0
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 12))
                                        Text("Restaurar")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Controles de accesibilidad (siempre visibles)
                            VStack(spacing: 24) {
                                // Interlineado
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: "text.alignleft")
                                                .foregroundColor(.primary)
                                            Text("INTERLINEADO")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.2f", lineHeight))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Slider(value: $lineHeight, in: 1.0...2.0, step: 0.1)
                                            .accentColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                // Espaciado entre caracteres
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: "textformat.abc")
                                                .foregroundColor(.primary)
                                            Text("ESPACIO ENTRE CARACTERES")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.0f%%", letterSpacing * 100))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Slider(value: $letterSpacing, in: 0.0...0.3, step: 0.01)
                                            .accentColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                // Espaciado entre palabras
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.left.and.right")
                                                .foregroundColor(.primary)
                                            Text("ESPACIADO ENTRE PALABRAS")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.0f%%", wordSpacing * 100))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Slider(value: $wordSpacing, in: 0.0...0.5, step: 0.01)
                                            .accentColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                // Márgenes
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: "decrease.indent")
                                                .foregroundColor(.primary)
                                            Text("MÁRGENES")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.0f%%", textMargins * 100))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Slider(value: $textMargins, in: 0.0...0.25, step: 0.01)
                                            .accentColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: min(UIScreen.main.bounds.width * 0.9, 380))
            .background(
                // Transparencia muy sutil (95% opaco)
                ZStack {
                    if colorScheme == .dark {
                        // En modo oscuro: fondo negro casi opaco
                        Color.black.opacity(0.95)
                    } else {
                        // En modo claro: fondo blanco casi opaco
                        Color.white.opacity(0.95)
                    }
                    
                    // Efecto de desenfoque muy mínimo
                    BlurView(style: colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
                        .opacity(0.2)
                }
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding()
        }
    }
    
    // Vista de botón de fuente
    @ViewBuilder
    private func fontButton(for fontOption: FontOption) -> some View {
        Button(action: {
            selectedFont = fontOption
            // Forzar actualización inmediata
            let currentIndex = currentPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    // Esto fuerza una recarga de la vista actual
                    currentPage = currentIndex
                }
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selectedFont == fontOption ? Color.blue.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
                        .frame(width: 60, height: 60)
                    
                    // Vista previa con la fuente
                    if fontOption == .original {
                        Text("Aa")
                            .font(.system(size: 20))
                            .foregroundColor(selectedFont == fontOption ? .blue : .primary)
                    } else if let fontName = fontOption.fontName {
                        Text("Aa")
                            .font(.custom(fontName, size: 20))
                            .foregroundColor(selectedFont == fontOption ? .blue : .primary)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(selectedFont == fontOption ? Color.blue : Color.clear, lineWidth: 2)
                )
                
                // Nombre de la fuente con altura fija
                Text(fontOption.rawValue)
                    .font(.caption)
                    .foregroundColor(selectedFont == fontOption ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80, height: 32) // Altura fija para todos los nombres
            }
            // Dimensiones fijas para todos los botones
            .frame(width: 80, height: 105)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 