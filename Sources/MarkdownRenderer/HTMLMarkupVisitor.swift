import Foundation
import Markdown

/// Walks a swift-markdown `Markup` tree and emits GitHub-flavored HTML.
///
/// This is an original implementation built on top of Apple's `swift-markdown`
/// (Apache-2.0). It is intentionally independent of any UI framework so it can be
/// compiled and unit-tested on any platform Swift supports, including Linux.
struct HTMLMarkupVisitor: MarkupVisitor {
    typealias Result = String

    /// When `false` (the default) any raw HTML found in the Markdown source is
    /// escaped and rendered as literal text. This prevents a malicious `.md` file
    /// from injecting `<script>` (or other active content) into the preview.
    let allowsRawHTML: Bool

    /// Tracks heading anchor slugs so duplicates get a numeric suffix, mirroring
    /// GitHub's behavior.
    private var usedSlugs: [String: Int] = [:]

    init(allowsRawHTML: Bool) {
        self.allowsRawHTML = allowsRawHTML
    }

    // MARK: - Helpers

    private mutating func renderChildren(of markup: Markup) -> String {
        var result = ""
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    private mutating func uniqueSlug(for text: String) -> String {
        var slug = ""
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else if scalar == " " || scalar == "-" || scalar == "_" {
                slug.append("-")
            }
        }
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "section" }
        if let count = usedSlugs[slug] {
            usedSlugs[slug] = count + 1
            return "\(slug)-\(count)"
        } else {
            usedSlugs[slug] = 1
            return slug
        }
    }

    // MARK: - MarkupVisitor

    mutating func defaultVisit(_ markup: Markup) -> String {
        return renderChildren(of: markup)
    }

    mutating func visitDocument(_ document: Document) -> String {
        return renderChildren(of: document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        return "<p>\(renderChildren(of: paragraph))</p>\n"
    }

    mutating func visitText(_ text: Text) -> String {
        return HTMLEscaping.escapeText(text.string)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = max(1, min(6, heading.level))
        let slug = uniqueSlug(for: heading.plainText)
        let inner = renderChildren(of: heading)
        let anchor = "<a class=\"anchor\" aria-hidden=\"true\" href=\"#\(HTMLEscaping.escapeAttribute(slug))\"></a>"
        return "<h\(level) id=\"\(HTMLEscaping.escapeAttribute(slug))\">\(anchor)\(inner)</h\(level)>\n"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        return "<em>\(renderChildren(of: emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        return "<strong>\(renderChildren(of: strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        return "<del>\(renderChildren(of: strikethrough))</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        return "<code>\(HTMLEscaping.escapeText(inlineCode.code))</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let escaped = HTMLEscaping.escapeText(codeBlock.code)
        if let language = codeBlock.language, !language.isEmpty {
            let cls = HTMLEscaping.escapeAttribute("language-\(language)")
            return "<pre><code class=\"\(cls)\">\(escaped)</code></pre>\n"
        }
        return "<pre><code>\(escaped)</code></pre>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        return "<blockquote>\n\(renderChildren(of: blockQuote))</blockquote>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        return "<hr />\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        return "<ul>\n\(renderChildren(of: unorderedList))</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let start = orderedList.startIndex
        let attr = start != 1 ? " start=\"\(start)\"" : ""
        return "<ol\(attr)>\n\(renderChildren(of: orderedList))</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let prefix: String
        let liClass: String
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            prefix = "<input type=\"checkbox\" disabled\(checked) /> "
            liClass = " class=\"task-list-item\""
        } else {
            prefix = ""
            liClass = ""
        }

        // In a "tight" list, an item holds a single paragraph and should render
        // its inline content directly (no <p>), matching GitHub. Items with
        // multiple block children (loose lists, nested lists) keep <p> wrapping.
        let blockChildren = Array(listItem.children)
        let inner: String
        if blockChildren.count == 1, let paragraph = blockChildren.first as? Paragraph {
            inner = renderChildren(of: paragraph)
        } else {
            inner = renderChildren(of: listItem)
        }
        return "<li\(liClass)>\(prefix)\(inner)</li>\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let href = HTMLEscaping.escapeAttribute(HTMLEscaping.sanitizeURL(link.destination ?? ""))
        return "<a href=\"\(href)\">\(renderChildren(of: link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = HTMLEscaping.escapeAttribute(HTMLEscaping.sanitizeURL(image.source ?? ""))
        let alt = HTMLEscaping.escapeAttribute(image.plainText)
        var titleAttr = ""
        if let title = image.title, !title.isEmpty {
            titleAttr = " title=\"\(HTMLEscaping.escapeAttribute(title))\""
        }
        return "<img src=\"\(src)\" alt=\"\(alt)\"\(titleAttr) />"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        return "<br />\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        return "\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        if allowsRawHTML {
            return html.rawHTML
        }
        return HTMLEscaping.escapeText(html.rawHTML)
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        if allowsRawHTML {
            return inlineHTML.rawHTML
        }
        return HTMLEscaping.escapeText(inlineHTML.rawHTML)
    }

    // MARK: - Tables (GFM)

    mutating func visitTable(_ table: Table) -> String {
        let alignments = table.columnAlignments

        func alignAttribute(forColumn index: Int) -> String {
            guard index < alignments.count, let alignment = alignments[index] else { return "" }
            switch alignment {
            case .left: return " align=\"left\""
            case .center: return " align=\"center\""
            case .right: return " align=\"right\""
            }
        }

        var html = "<table>\n<thead>\n<tr>\n"
        var headColumn = 0
        for child in table.head.children {
            html += "<th\(alignAttribute(forColumn: headColumn))>\(renderChildren(of: child))</th>\n"
            headColumn += 1
        }
        html += "</tr>\n</thead>\n<tbody>\n"
        for row in table.body.children {
            html += "<tr>\n"
            var bodyColumn = 0
            for cell in row.children {
                html += "<td\(alignAttribute(forColumn: bodyColumn))>\(renderChildren(of: cell))</td>\n"
                bodyColumn += 1
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table>\n"
        return html
    }
}
