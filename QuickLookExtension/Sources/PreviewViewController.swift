import Cocoa
import Quartz          // QuickLookUI (QLPreviewingController) lives here on macOS
import WebKit
import MarkdownRenderer

/// The principal class of the Quick Look Preview Extension.
///
/// When you select a Markdown file in Finder and press the spacebar, the system
/// instantiates this controller, hands it the file URL, and displays its view.
/// We read the file, render it to a self-contained HTML document, and show it in
/// a `WKWebView`.
final class PreviewViewController: NSViewController, QLPreviewingController {

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        // All CSS/JS is inlined into the rendered HTML, so the preview needs no
        // network access. JavaScript stays enabled only so the bundled
        // highlight.js can colorize code blocks; untrusted raw HTML in the
        // source is escaped by the renderer (allowsRawHTML == false), so a
        // malicious file cannot inject its own <script>.
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        return webView
    }()

    override func loadView() {
        let container = NSView()
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        self.view = container
    }

    // MARK: - QLPreviewingController

    /// Modern single-file preview entry point (macOS 12+).
    func preparePreviewOfFile(at url: URL) async throws {
        let markdown = try Self.readMarkdown(at: url)
        let html = MarkdownRenderer.renderFullHTMLDocument(
            from: markdown,
            title: url.lastPathComponent
        )
        await MainActor.run {
            // baseURL points at the file's directory so relative image links can
            // resolve when the sandbox grants access.
            self.webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        }
    }

    // MARK: - Helpers

    /// Reads the file as UTF-8, falling back to a lenient decode and then to
    /// Latin-1 so previews never fail purely due to text encoding.
    private static func readMarkdown(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        return String(decoding: data, as: UTF8.self)
    }
}
