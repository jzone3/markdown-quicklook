import SwiftUI
import WebKit
import MarkdownRenderer

/// A SwiftUI wrapper around `WKWebView` that renders Markdown using the exact
/// same `MarkdownRenderer` path as the Quick Look extension. Used by the host app
/// to show a live preview so you can confirm rendering before enabling the
/// extension.
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = MarkdownRenderer.renderFullHTMLDocument(from: markdown, title: "Preview")
        webView.loadHTMLString(html, baseURL: nil)
    }
}
