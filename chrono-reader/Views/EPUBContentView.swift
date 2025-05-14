import SwiftUI
import WebKit

struct EPUBContentView: UIViewRepresentable {
    let html: String
    let baseURL: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        // Configurar el estilo base
        let css = """
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 18px;
                line-height: 1.6;
                margin: 20px;
                padding: 0;
                color: #333;
                background-color: transparent;
            }
            img {
                max-width: 100%;
                height: auto;
                display: block;
                margin: 1em auto;
            }
            h1, h2, h3, h4, h5, h6 {
                margin-top: 1.5em;
                margin-bottom: 0.5em;
                line-height: 1.2;
            }
            p {
                margin: 1em 0;
                text-align: justify;
            }
        """
        
        let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>\(css)</style>
            </head>
            <body>
                \(html)
            </body>
            </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: baseURL)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No es necesario actualizar la vista
    }
} 