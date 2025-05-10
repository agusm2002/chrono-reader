import Foundation
import WebKit
import UIKit

class EPUBVisualPaginator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView!
    private var continuation: CheckedContinuation<[String], Never>?
    private var pageHeight: CGFloat = 0
    private var pageWidth: CGFloat = 0
    private var html: String = ""

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        webView.navigationDelegate = self
        webView.isHidden = true
        webView.scrollView.isScrollEnabled = false
        UIApplication.shared.windows.first?.addSubview(webView)
    }

    deinit {
        webView?.removeFromSuperview()
    }

    func paginateVisual(html: String, pageHeight: CGFloat, pageWidth: CGFloat) async -> [String] {
        self.pageHeight = pageHeight
        self.pageWidth = pageWidth
        self.html = html
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            DispatchQueue.main.async {
                self.webView.frame = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Ejecutar JS para paginar visualmente por bloques
        let js = """
        (function() {
            var blocks = Array.from(document.body.querySelectorAll('p, div, h1, h2, h3, h4, h5, h6, ul, ol, li, blockquote, pre'));
            var pages = [];
            var current = [];
            var currentHeight = 0;
            var maxHeight = window.innerHeight;
            for (var i = 0; i < blocks.length; i++) {
                var rect = blocks[i].getBoundingClientRect();
                var blockHeight = rect.height;
                // Si el bloque no cabe, empezar nueva página
                if (currentHeight + blockHeight > maxHeight && current.length > 0) {
                    pages.push(current.map(b => b.outerHTML).join(''));
                    current = [];
                    currentHeight = 0;
                }
                current.push(blocks[i]);
                currentHeight += blockHeight;
            }
            if (current.length > 0) {
                pages.push(current.map(b => b.outerHTML).join(''));
            }
            return pages;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            if let pages = result as? [String] {
                self.continuation?.resume(returning: pages)
            } else {
                self.continuation?.resume(returning: [])
            }
        }
    }
} 