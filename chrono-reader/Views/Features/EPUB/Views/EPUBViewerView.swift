//
//  EPUBViewerView.swift
//  chrono-reader
//
//  Created by Agustin Monti on 02/03/2025.
//

import SwiftUI
import WebKit

// Vista contenedora personalizada para manejar gestos
struct EPUBGestureContainer: UIViewRepresentable {
    var onTap: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: EPUBGestureContainer
        
        init(_ parent: EPUBGestureContainer) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            parent.onTap()
        }
    }
}

struct EPUBViewerView: View {
    @StateObject var viewModel: EPUBViewerViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showControls: Bool = true
    @State private var showTOC: Bool = false
    @State private var showSettings: Bool = false
    @State private var initialTouchY: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showHUD: Bool = true
    
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
            
            // Contenedor de gestos que cubre toda la pantalla
            EPUBGestureContainer {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls.toggle()
                    showHUD.toggle()
                }
                
                if showControls {
                    resetControlsTimer()
                } else {
                    controlsTimer?.invalidate()
                    controlsTimer = nil
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Contenido principal - PageView
                EPUBPageView(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.horizontal)
            }
            
            // HUD con botones de navegación
            if showHUD {
                VStack {
                    HStack {
                        // Botón de regresar (alineado con el de la barra superior)
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        .padding(.top, 30)
                        
                        Spacer()
                        
                        // Botón del menú de secciones
                        Button(action: {
                            withAnimation(.spring()) {
                                showTOC = true
                            }
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 30)
                    }
                    Spacer()
                }
            }
            
            // Controles de navegación (solo se muestran cuando showHUD es false)
            if showControls && !showHUD {
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
                            showHUD = true
                        }
                        resetControlsTimer()
                    }
                    // Si arrastró hacia arriba en la parte inferior, mostrar controles
                    else if dragDirection < -50 && value.startLocation.y > UIScreen.main.bounds.height - 100 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showControls = true
                            showHUD = true
                        }
                        resetControlsTimer()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
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
                TabView(selection: $viewModel.currentPosition) {
                    ForEach(0..<(viewModel.epubBook?.totalPositions ?? 0), id: \.self) { position in
                        EPUBPageContentView(viewModel: viewModel, position: position)
                            .tag(position)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: viewModel.currentPosition) { newPosition in
                    viewModel.updateCurrentChapter()
                }
            } else {
                // Paginación vertical
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<(viewModel.epubBook?.totalPositions ?? 0), id: \.self) { position in
                            EPUBPageContentView(viewModel: viewModel, position: position)
                                .frame(width: geometry.size.width, 
                                       height: geometry.size.height)
                                .id(position)
                        }
                    }
                }
                .onAppear {
                    // Scroll to the current position when appearing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let scrollView = UIApplication.shared.windows.first?.rootViewController?.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                            let contentOffset = CGPoint(x: 0, y: CGFloat(viewModel.currentPosition) * geometry.size.height)
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
    let position: Int
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.isPagingEnabled = true
        webView.scrollView.bounces = false
        
        // Configurar el viewport para que ocupe todo el ancho
        let viewportScript = WKUserScript(
            source: "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'); document.getElementsByTagName('head')[0].appendChild(meta);",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(viewportScript)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let epubBook = viewModel.epubBook else { return }
        // Encontrar el recurso y página correspondiente a esta posición
        var currentPosition = 0
        var foundResourceId: String? = nil
        var foundPageIndex = 0
        for spineRef in epubBook.spine.spineReferences {
            if let resource = epubBook.pagedResources[spineRef.resourceId] {
                if position < currentPosition + resource.totalPages {
                    foundResourceId = spineRef.resourceId
                    foundPageIndex = position - currentPosition
                    break
                }
                currentPosition += resource.totalPages
            }
        }
        guard let resourceId = foundResourceId,
              let spineRef = epubBook.spine.spineReferences.first(where: { $0.resourceId == resourceId }),
              let resource = epubBook.resources[resourceId],
              let spineIndex = epubBook.spine.spineReferences.firstIndex(where: { $0.resourceId == resourceId }) else { return }
        if let pageContent = viewModel.getPageContent(for: position) {
            // Obtener la ruta base para recursos como imágenes y CSS
            var baseURL: URL? = nil
            let resourceURL = URL(fileURLWithPath: resource.fullHref)
            baseURL = resourceURL.deletingLastPathComponent()
            
            // Obtener las dimensiones de la pantalla
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            
            // Crear HTML base con estilos que se adaptan a la configuración
            let baseHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset=\"utf-8\">
                <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">
                <style>
                    :root {
                        --page-width: \(screenWidth)px;
                        --page-height: \(screenHeight)px;
                        --margin-horizontal: 40px;
                        --margin-vertical: 40px;
                        --content-width: calc(var(--page-width) - (2 * var(--margin-horizontal)));
                        --content-height: calc(var(--page-height) - (2 * var(--margin-vertical)));
                    }
                    
                    html {
                        width: 100%;
                        height: 100%;
                        margin: 0;
                        padding: 0;
                        overflow: hidden;
                    }
                    
                    body {
                        background-color: \(colorToCSSString(viewModel.readerConfig.theme.backgroundColor));
                        color: \(colorToCSSString(viewModel.readerConfig.theme.textColor));
                        margin: 0;
                        padding: 0;
                        width: 100%;
                        height: 100%;
                        overflow: hidden;
                    }
                    
                    .content-wrapper {
                        width: var(--content-width);
                        height: var(--content-height);
                        margin: var(--margin-vertical) var(--margin-horizontal);
                        column-width: var(--content-width);
                        column-gap: 0;
                        column-fill: auto;
                        text-align: justify;
                        hyphens: auto;
                        -webkit-hyphens: auto;
                        position: relative;
                    }
                    
                    p {
                        margin: 0;
                        padding: 0;
                        line-height: var(--line-height);
                        text-align: justify;
                        orphans: 2;
                        widows: 2;
                        break-inside: avoid;
                        page-break-inside: avoid;
                        -webkit-column-break-inside: avoid;
                    }
                    
                    /* Reglas para el corte de palabras */
                    .content-wrapper {
                        word-wrap: break-word;
                        overflow-wrap: break-word;
                        word-break: break-word;
                        -webkit-hyphenate-character: auto;
                        hyphenate-character: auto;
                    }
                    
                    /* Asegurar que los párrafos no se corten en lugares inapropiados */
                    p {
                        break-after: auto;
                        break-before: auto;
                        page-break-after: auto;
                        page-break-before: auto;
                    }
                    
                    /* Forzar el corte de palabras cuando sea necesario */
                    .content-wrapper {
                        overflow: hidden;
                        position: relative;
                    }
                </style>
            </head>
            <body>
                <div class=\"content-wrapper\">\(pageContent)</div>
            </body>
            </html>
            """
            // Cargar el HTML en el webView
            if let baseURL = baseURL {
                webView.loadHTMLString(baseHTML, baseURL: baseURL)
            } else {
                webView.loadHTMLString(baseHTML, baseURL: nil)
            }
        }
    }
    
    private func colorToCSSString(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
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