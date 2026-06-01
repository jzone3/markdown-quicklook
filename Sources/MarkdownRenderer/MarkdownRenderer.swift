import Foundation
import Markdown

/// Options controlling how Markdown is converted to HTML.
public struct MarkdownRenderingOptions {
    /// When `true`, raw HTML embedded in the Markdown source is passed through
    /// verbatim. When `false` (default) it is escaped and shown as literal text.
    /// Keeping this `false` prevents `<script>` injection from untrusted files.
    public var allowsRawHTML: Bool

    /// When `true` (default) highlight.js and a GitHub theme are embedded so code
    /// blocks are syntax highlighted in a `WKWebView`.
    public var enableSyntaxHighlighting: Bool

    public init(allowsRawHTML: Bool = false, enableSyntaxHighlighting: Bool = true) {
        self.allowsRawHTML = allowsRawHTML
        self.enableSyntaxHighlighting = enableSyntaxHighlighting
    }

    public static let `default` = MarkdownRenderingOptions()
}

/// Converts Markdown text into styled, self-contained HTML.
///
/// The output of ``renderFullHTMLDocument(from:title:options:)`` inlines all CSS
/// and JavaScript so it can be handed straight to `WKWebView.loadHTMLString` from
/// inside a sandboxed Quick Look extension without needing any network or extra
/// file access.
public enum MarkdownRenderer {

    /// Renders just the HTML body fragment (no `<html>`, CSS, or JS).
    public static func renderHTMLFragment(
        from markdown: String,
        options: MarkdownRenderingOptions = .default
    ) -> String {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        var visitor = HTMLMarkupVisitor(allowsRawHTML: options.allowsRawHTML)
        return visitor.visit(document)
    }

    /// Renders a complete, self-contained HTML document with inlined CSS/JS.
    public static func renderFullHTMLDocument(
        from markdown: String,
        title: String = "Markdown Preview",
        options: MarkdownRenderingOptions = .default
    ) -> String {
        let body = renderHTMLFragment(from: markdown, options: options)
        let escapedTitle = HTMLEscaping.escapeText(title)

        var styles = ""
        styles += "<style>\n\(BundledAsset.githubMarkdownCSS)\n</style>\n"
        styles += "<style>\n\(layoutCSS)\n</style>\n"

        var scripts = ""
        if options.enableSyntaxHighlighting {
            styles += "<style>\n\(BundledAsset.highlightLightCSS)\n</style>\n"
            styles += "<style>\n@media (prefers-color-scheme: dark) {\n\(BundledAsset.highlightDarkCSS)\n}\n</style>\n"
            scripts += "<script>\n\(BundledAsset.highlightJS)\n</script>\n"
            scripts += "<script>\n\(highlightInvocationJS)\n</script>\n"
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="light dark" />
        <title>\(escapedTitle)</title>
        \(styles)</head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        \(scripts)</body>
        </html>
        """
    }

    /// Extra layout CSS layered on top of github-markdown-css to center content
    /// and give the preview comfortable padding.
    private static let layoutCSS = """
    html, body { margin: 0; padding: 0; }
    /* Full-bleed background matching github-markdown-css's canvas color so the
       centered content's side margins blend in, in both light and dark mode. */
    body { background-color: #ffffff; }
    @media (prefers-color-scheme: dark) { body { background-color: #0d1117; } }
    .markdown-body {
        box-sizing: border-box;
        min-width: 200px;
        max-width: 980px;
        margin: 0 auto;
        padding: 28px 36px 48px;
        background-color: transparent;
    }
    .markdown-body .anchor { display: none; }
    @media (max-width: 767px) {
        .markdown-body { padding: 16px; }
    }
    """

    private static let highlightInvocationJS = """
    document.addEventListener('DOMContentLoaded', function () {
        if (!window.hljs) { return; }
        document.querySelectorAll('pre code').forEach(function (block) {
            try { window.hljs.highlightElement(block); } catch (e) {}
        });
    });
    """
}
