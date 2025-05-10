import Foundation
import WebKit
import UIKit

class EPUBRealPaginator: NSObject, WKNavigationDelegate {
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

    func paginate(html: String, pageHeight: CGFloat, pageWidth: CGFloat) async -> [String] {
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
        // Ejecutar JS para obtener scrollHeight y dividir en páginas
        let js = "document.body.scrollHeight"
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            guard let scrollHeight = (result as? NSNumber)?.floatValue, scrollHeight > 0 else {
                self.continuation?.resume(returning: [])
                return
            }
            let numPages = Int(ceil(scrollHeight / Float(self.pageHeight)))
            self.extractPages(numPages: numPages)
        }
    }

    private func extractPages(numPages: Int) {
        var pages: [String] = []
        let group = DispatchGroup()
        for i in 0..<numPages {
            group.enter()
            let offset = CGFloat(i) * pageHeight
            let js = """
                window.scrollTo(0, \(offset));
                document.documentElement.scrollTop = \(offset);
                document.body.scrollTop = \(offset);
                (function() {
                    var range = document.createRange();
                    var node = document.body;
                    range.selectNodeContents(node);
                    var rects = range.getClientRects();
                    var html = '';
                    for (var j = 0; j < rects.length; j++) {
                        if (rects[j].top >= 0 && rects[j].bottom <= window.innerHeight) {
                            html += node.innerHTML;
                            break;
                        }
                    }
                    return html;
                })();
            """
            webView.evaluateJavaScript(js) { result, error in
                if let html = result as? String {
                    pages.append(html)
                } else {
                    pages.append("")
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.continuation?.resume(returning: pages)
        }
    }
} 