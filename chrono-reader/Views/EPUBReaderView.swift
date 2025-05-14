import SwiftUI

struct EPUBBasicReaderView: View {
    let document: EPUBBook
    @State private var currentPage = 0
    @State private var pageContent: [String] = []
    @State private var isLoading = true
    @State private var baseURL: URL?
    
    // Configuración de lectura
    private let pageWidth: CGFloat = UIScreen.main.bounds.width
    private let pageHeight: CGFloat = UIScreen.main.bounds.height
    private let pageMargin: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                ProgressView("Cargando...")
            } else if let baseURL = baseURL {
                TabView(selection: $currentPage) {
                    ForEach(0..<pageContent.count, id: \.self) { index in
                        EPUBBasicPageView(content: pageContent[index], baseURL: baseURL)
                            .frame(width: pageWidth, height: pageHeight)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .environment(\.layoutDirection, document.spine.isRightToLeft ? .rightToLeft : .leftToRight)
            } else {
                Text("Error: No se pudo determinar la ubicación base del libro")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            loadContent()
        }
    }
    
    private func loadContent() {
        // Cargar el contenido de las páginas
        Task {
            do {
                var content: [String] = []
                var firstResourceURL: URL? = nil
                
                for spineRef in document.spine.spineReferences {
                    if let resource = document.resources[spineRef.resourceId] {
                        // Obtener la URL base del primer recurso
                        if firstResourceURL == nil {
                            firstResourceURL = URL(fileURLWithPath: resource.fullHref).deletingLastPathComponent()
                        }
                        
                        if let data = resource.data,
                           let html = String(data: data, encoding: .utf8) {
                            content.append(html)
                        }
                    }
                }
                
                await MainActor.run {
                    self.baseURL = firstResourceURL
                    self.pageContent = content
                    self.isLoading = false
                }
            } catch {
                print("Error cargando contenido: \(error)")
            }
        }
    }
}

struct EPUBBasicPageView: View {
    let content: String
    let baseURL: URL
    
    var body: some View {
        EPUBContentView(html: content, baseURL: baseURL)
            .edgesIgnoringSafeArea(.all)
    }
}

// Vista previa para desarrollo
struct EPUBBasicReaderView_Previews: PreviewProvider {
    static var previews: some View {
        // TODO: Implementar vista previa con datos de ejemplo
        Text("Vista previa no disponible")
    }
} 