//
//  EPUBViewerView.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import SwiftUI
import WebKit

struct EPUBViewerView: View {
    @StateObject var viewModel: EPUBViewerViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showControls: Bool = true
    @State private var showTOC: Bool = false
    @State private var showSettings: Bool = false
    @State private var initialTouchY: CGFloat = 0
    @State private var isDragging: Bool = false
    
    // Gesture variables
    private let controlsAutoHideDelay: Double = 3.0
    @State private var controlsTimer: Timer? = nil
    
    init(book: CompleteBook) {
        _viewModel = StateObject(wrappedValue: EPUBViewerViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
            // Fondo que se adapta al tema
            viewModel.readerConfig.theme.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Contenido principal - PageView
                EPUBPageView(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.horizontal)
            }
            
            // Controles de navegación
            if showControls {
                VStack {
                    // Barra superior
                    topBar
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.6), Color.black.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                    
                    // Barra inferior
                    bottomBar
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0), Color.black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Tabla de contenidos
            if showTOC {
                EPUBTableOfContentsView(
                    viewModel: viewModel,
                    isPresented: $showTOC
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // Panel de configuración
            if showSettings {
                EPUBSettingsView(
                    config: $viewModel.readerConfig,
                    isPresented: $showSettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .persistentSystemOverlaysSupressed(showControls: showControls)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if !isDragging {
                        initialTouchY = value.startLocation.y
                        isDragging = true
                    }
                    
                    // Determinar la dirección vertical de arrastre
                    let dragDirection = value.location.y - initialTouchY
                    
                    // Si arrastró hacia abajo en la parte superior, mostrar controles
                    if dragDirection > 50 && value.startLocation.y < 100 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showControls = true
                        }
                        resetControlsTimer()
                    }
                    // Si arrastró hacia arriba en la parte inferior, mostrar controles
                    else if dragDirection < -50 && value.startLocation.y > UIScreen.main.bounds.height - 100 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showControls = true
                        }
                        resetControlsTimer()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            
            if showControls {
                resetControlsTimer()
            } else {
                controlsTimer?.invalidate()
                controlsTimer = nil
            }
        }
        .onAppear {
            resetControlsTimer()
            // Iniciar la carga del libro
            Task {
                await viewModel.loadBook()
            }
        }
        .onDisappear {
            controlsTimer?.invalidate()
        }
    }
    
    // Barra superior
    private var topBar: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding()
            }
            
            Spacer()
            
            Text(viewModel.currentChapterTitle)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    showTOC = true
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .padding(.top, 30)
        .padding(.bottom, 10)
    }
    
    // Barra inferior
    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Control deslizante de progreso
            ProgressView(value: viewModel.readingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.white))
                .padding(.horizontal)
            
            HStack {
                // Botón de capítulo anterior
                Button(action: {
                    viewModel.previousChapter()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                // Texto de progreso
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Configuración
                Button(action: {
                    withAnimation(.spring()) {
                        showSettings = true
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding()
                }
                
                // Botón de capítulo siguiente
                Button(action: {
                    viewModel.nextChapter()
                }) {
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    // Reiniciar el temporizador para ocultar los controles
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: controlsAutoHideDelay, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

// Vista del contenido de la página
struct EPUBPageView: View {
    @ObservedObject var viewModel: EPUBViewerViewModel
    
    var body: some View {
        GeometryReader { geometry in
            if viewModel.readerConfig.scrollDirection == .horizontal {
                // Paginación horizontal
                TabView(selection: $viewModel.currentPage) {
                    ForEach(0..<viewModel.totalPages, id: \.self) { index in
                        EPUBPageContentView(viewModel: viewModel, pageIndex: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: viewModel.currentPage) { _ in
                    viewModel.updateCurrentChapter()
                }
            } else {
                // Paginación vertical
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<viewModel.totalPages, id: \.self) { index in
                            EPUBPageContentView(viewModel: viewModel, pageIndex: index)
                                .frame(width: geometry.size.width, 
                                       height: geometry.size.height)
                                .id(index)
                        }
                    }
                }
                .onAppear {
                    // Scroll to the current page when appearing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let scrollView = UIApplication.shared.windows.first?.rootViewController?.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                            let contentOffset = CGPoint(x: 0, y: CGFloat(viewModel.currentPage) * geometry.size.height)
                            scrollView.setContentOffset(contentOffset, animated: false)
                        }
                    }
                }
            }
        }
    }
}

// Vista para mostrar el contenido HTML de una página
struct EPUBPageContentView: UIViewRepresentable {
    @ObservedObject var viewModel: EPUBViewerViewModel
    var pageIndex: Int
    
    func makeUIView(context: Context) -> WKWebView {
        // Configurar preferencias de WebView
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = false // Deshabilitar JavaScript por seguridad
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        // Crear el WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let epubBook = viewModel.epubBook,
              pageIndex < epubBook.spine.spineReferences.count else { return }
        
        let spineRef = epubBook.spine.spineReferences[pageIndex]
        
        if let chapterContent = viewModel.getPageContent(for: pageIndex) {
            // Obtener la ruta base para recursos como imágenes y CSS
            var baseURL: URL? = nil
            if let resource = epubBook.resources[spineRef.resourceId] {
                let resourceURL = URL(fileURLWithPath: resource.fullHref)
                baseURL = resourceURL.deletingLastPathComponent()
            }
            
            // Crear HTML base con estilos que se adaptan a la configuración
            let baseHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <meta charset="utf-8">
                <style>
                    body {
                        font-family: \(viewModel.readerConfig.fontName), -apple-system, sans-serif;
                        font-size: \(Int(viewModel.readerConfig.textSize))px;
                        line-height: \(viewModel.readerConfig.lineHeight);
                        color: \(colorToCSSString(viewModel.readerConfig.theme.textColor));
                        background-color: \(colorToCSSString(viewModel.readerConfig.theme.backgroundColor));
                        padding: 20px;
                        margin: 0;
                    }
                    
                    /* Estilos para imágenes */
                    img, svg, audio, video {
                        max-height: 95% !important;
                        max-width: 100% !important;
                        box-sizing: border-box;
                        object-fit: contain;
                        page-break-inside: avoid;
                        display: block;
                        margin: 1em auto;
                        height: auto;
                    }
                    
                    img { 
                        -webkit-user-select: none; 
                        user-select: none;
                    }
                    
                    /* Estilos para asegurar que los cuadros de texto sean legibles */
                    p, div {
                        max-width: 100%;
                        word-wrap: break-word;
                    }
                    
                    /* Estilos para encabezados */
                    h1, h2, h3, h4, h5, h6 {
                        line-height: 1.2;
                        margin-top: 1.5em;
                        margin-bottom: 0.5em;
                    }
                    
                    /* Estilos para enlaces */
                    a {
                        color: #0066cc;
                        text-decoration: none;
                    }
                    
                    /* Estilos para tablas */
                    table {
                        max-width: 100%;
                        border-collapse: collapse;
                        margin: 1em 0;
                    }
                    
                    /* Ajustes para el tema oscuro */
                    @media (prefers-color-scheme: dark) {
                        a {
                            color: #66a9ff;
                        }
                    }
                </style>
            </head>
            <body>
                \(chapterContent)
            </body>
            </html>
            """
            
            // Cargar el HTML con la URL base para resolver rutas relativas
            webView.loadHTMLString(baseHTML, baseURL: baseURL)
        }
    }
    
    // Convertir SwiftUI Color a string CSS
    private func colorToCSSString(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EPUBPageContentView
        
        init(_ parent: EPUBPageContentView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Actualizar la vista cuando se carga el contenido
            DispatchQueue.main.async {
                if self.parent.pageIndex == self.parent.viewModel.currentPage {
                    self.parent.viewModel.updatePageProgress(for: self.parent.pageIndex)
                }
            }
        }
    }
}

// Vista para la tabla de contenidos
struct EPUBTableOfContentsView: View {
    @ObservedObject var viewModel: EPUBViewerViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Fondo semitransparente
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Panel de tabla de contenidos
            VStack(alignment: .leading, spacing: 0) {
                // Encabezado del panel
                HStack {
                    Text("Tabla de Contenidos")
                        .font(.title3)
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
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                Divider()
                
                // Lista de capítulos
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(viewModel.tableOfContents.indices, id: \.self) { index in
                            let item = viewModel.tableOfContents[index]
                            
                            Button(action: {
                                viewModel.navigateToChapter(resourceId: item.resourceId)
                                withAnimation(.spring()) {
                                    isPresented = false
                                }
                            }) {
                                HStack {
                                    Text(item.title)
                                        .padding(.leading, CGFloat(item.level * 15))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                    
                                    if viewModel.isCurrentChapter(item.resourceId) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                            }
                            .background(
                                Group {
                                    if viewModel.isCurrentChapter(item.resourceId) {
                                        Color.blue.opacity(0.1)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            
                            // Mostrar los hijos del elemento actual
                            ForEach(item.children.indices, id: \.self) { childIndex in
                                let child = item.children[childIndex]
                                
                                Button(action: {
                                    viewModel.navigateToChapter(resourceId: child.resourceId)
                                    withAnimation(.spring()) {
                                        isPresented = false
                                    }
                                }) {
                                    HStack {
                                        Text(child.title)
                                            .padding(.leading, CGFloat(child.level * 15))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        
                                        Spacer()
                                        
                                        if viewModel.isCurrentChapter(child.resourceId) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .contentShape(Rectangle())
                                }
                                .background(
                                    Group {
                                        if viewModel.isCurrentChapter(child.resourceId) {
                                            Color.blue.opacity(0.1)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                            }
                            
                            Divider()
                        }
                    }
                    .padding(.vertical)
                }
            }
            .frame(width: min(UIScreen.main.bounds.width * 0.85, 320))
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
        }
        .zIndex(10)
    }
}

// Vista para la configuración del lector
struct EPUBSettingsView: View {
    @Binding var config: EPUBReaderConfig
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Fondo semitransparente
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Panel de configuración
            VStack(spacing: 20) {
                // Encabezado
                HStack {
                    Text("Configuración")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                
                // Tamaño de texto
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tamaño de texto")
                        .font(.headline)
                    
                    HStack {
                        Text("A")
                            .font(.system(size: 14))
                        
                        Slider(value: $config.textSize, in: 12...28, step: 1)
                        
                        Text("A")
                            .font(.system(size: 24))
                    }
                }
                
                // Altura de línea
                VStack(alignment: .leading, spacing: 10) {
                    Text("Altura de línea")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "text.alignleft")
                            .imageScale(.small)
                        
                        Slider(value: $config.lineHeight, in: 1.0...2.5, step: 0.1)
                        
                        Image(systemName: "text.alignleft")
                            .imageScale(.large)
                    }
                }
                
                // Selección de fuente
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fuente")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(["SF Pro Text", "New York", "Palatino", "Georgia", "Avenir Next", "San Francisco"], id: \.self) { fontName in
                                Button(action: {
                                    config.fontName = fontName
                                }) {
                                    Text(fontName)
                                        .font(.custom(fontName, size: 16))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(config.fontName == fontName ?
                                                      Color.blue.opacity(0.5) :
                                                        Color(UIColor.secondarySystemBackground))
                                        )
                                        .foregroundColor(config.fontName == fontName ?
                                                        .white : .primary)
                                }
                            }
                        }
                    }
                }
                
                // Modo de desplazamiento
                VStack(alignment: .leading, spacing: 10) {
                    Text("Modo de desplazamiento")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            config.scrollDirection = .horizontal
                        }) {
                            VStack {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.title3)
                                Text("Horizontal")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(config.scrollDirection == .horizontal ?
                                          Color.blue.opacity(0.5) :
                                            Color(UIColor.secondarySystemBackground))
                            )
                            .foregroundColor(config.scrollDirection == .horizontal ?
                                            .white : .primary)
                        }
                        
                        Button(action: {
                            config.scrollDirection = .vertical
                        }) {
                            VStack {
                                Image(systemName: "arrow.up.and.down")
                                    .font(.title3)
                                Text("Vertical")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(config.scrollDirection == .vertical ?
                                          Color.blue.opacity(0.5) :
                                            Color(UIColor.secondarySystemBackground))
                            )
                            .foregroundColor(config.scrollDirection == .vertical ?
                                            .white : .primary)
                        }
                    }
                    .padding(.bottom, 5)
                }
                
                // Temas
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tema")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            config.theme = .light
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                        .opacity(config.theme == .light ? 1 : 0)
                                )
                        }
                        
                        Button(action: {
                            config.theme = .sepia
                        }) {
                            Circle()
                                .fill(Color(red: 0.98, green: 0.94, blue: 0.85))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(red: 0.36, green: 0.24, blue: 0.09))
                                        .opacity(config.theme == .sepia ? 1 : 0)
                                )
                        }
                        
                        Button(action: {
                            config.theme = .dark
                        }) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .opacity(config.theme == .dark ? 1 : 0)
                                )
                        }
                    }
                }
            }
            .padding()
            .frame(width: min(UIScreen.main.bounds.width * 0.9, 360))
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
        }
        .zIndex(10)
    }
}