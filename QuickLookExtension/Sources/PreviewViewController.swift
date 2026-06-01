import Cocoa
import Quartz          // QuickLookUI (QLPreviewingController) lives here on macOS

/// The principal class of the Quick Look Preview Extension.
///
/// When you select a Markdown file in Finder and press the spacebar, the system
/// instantiates this controller, hands it the file URL, and displays its view.
/// We read the file, render it to native attributed text, and show it in a text view.
final class PreviewViewController: NSViewController, QLPreviewingController {

    private lazy var textView: NSTextView = {
        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        return textView
    }()

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView
        return scrollView
    }()

    override func loadView() {
        self.view = scrollView
    }

    // MARK: - QLPreviewingController

    /// Modern single-file preview entry point (macOS 12+).
    func preparePreviewOfFile(at url: URL) async throws {
        let markdown = try Self.readMarkdown(at: url)
        let attributed = Self.renderMarkdown(markdown)
        await MainActor.run {
            self.textView.textStorage?.setAttributedString(attributed)
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

    private static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                appendCode(codeLines.joined(separator: "\n"), to: output)
                index += 1
                continue
            }

            if let heading = heading(from: trimmed) {
                appendInline(
                    heading.text,
                    to: output,
                    font: NSFont.boldSystemFont(ofSize: heading.size),
                    color: .labelColor,
                    paragraph: paragraph(spacingBefore: heading.before, spacingAfter: heading.after)
                )
                index += 1
                continue
            }

            if isThematicBreak(trimmed) {
                appendPlain("────────────", to: output, font: .systemFont(ofSize: 14), color: .separatorColor, paragraph: paragraph(spacingBefore: 10, spacingAfter: 18))
                index += 1
                continue
            }

            if isTableLine(trimmed) {
                var tableLines: [String] = []
                while index < lines.count && isTableLine(lines[index].trimmingCharacters(in: .whitespaces)) {
                    tableLines.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                appendTable(tableLines, to: output)
                continue
            }

            if let item = listItem(from: line) {
                appendListItem(item, to: output)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                appendInline(
                    trimmed.dropFirst().trimmingCharacters(in: .whitespaces),
                    to: output,
                    font: .systemFont(ofSize: 14),
                    color: .secondaryLabelColor,
                    paragraph: paragraph(spacingBefore: 8, spacingAfter: 18, headIndent: 12, firstLineHeadIndent: 12)
                )
                index += 1
                continue
            }

            var paragraphLines = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("```") || heading(from: next) != nil || isThematicBreak(next) || isTableLine(next) || listItem(from: lines[index]) != nil || next.hasPrefix(">") {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            appendInline(
                paragraphLines.joined(separator: " "),
                to: output,
                font: .systemFont(ofSize: 14),
                color: .labelColor,
                paragraph: paragraph(spacingAfter: 14)
            )
        }

        return output
    }

    private static func appendPlain(_ text: some StringProtocol, to output: NSMutableAttributedString, font: NSFont, color: NSColor, paragraph: NSParagraphStyle) {
        let string = String(text)
        let block = NSMutableAttributedString(string: string + "\n", attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        output.append(block)
    }

    private static func appendInline(_ text: some StringProtocol, to output: NSMutableAttributedString, font: NSFont, color: NSColor, paragraph: NSParagraphStyle) {
        let block = NSMutableAttributedString(attributedString: inline(String(text), font: font, color: color))
        block.append(NSAttributedString(string: "\n", attributes: [.font: font, .foregroundColor: color]))
        block.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: block.length))
        output.append(block)
    }

    private static func appendCode(_ text: String, to output: NSMutableAttributedString) {
        appendPlain(text, to: output, font: .monospacedSystemFont(ofSize: 12.5, weight: .regular), color: .labelColor, paragraph: paragraph(spacingBefore: 8, spacingAfter: 18, lineHeightMultiple: 1.25))
    }

    private static func appendTable(_ lines: [String], to output: NSMutableAttributedString) {
        guard let table = parseTable(lines) else {
            appendCode(lines.joined(separator: "\n"), to: output)
            return
        }

        let textTable = NSTextTable()
        textTable.numberOfColumns = table.columnCount
        textTable.layoutAlgorithm = .fixedLayoutAlgorithm
        textTable.setBorderColor(.separatorColor)
        textTable.setWidth(0.7, type: .absoluteValueType, for: .border)
        textTable.collapsesBorders = true

        for rowIndex in table.rows.indices {
            for columnIndex in 0..<table.columnCount {
                let cellText = table.rows[rowIndex][columnIndex]
                let block = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: columnIndex,
                    columnSpan: 1
                )
                block.setWidth(6, type: .absoluteValueType, for: .padding, edge: .minX)
                block.setWidth(6, type: .absoluteValueType, for: .padding, edge: .maxX)
                block.setWidth(4, type: .absoluteValueType, for: .padding, edge: .minY)
                block.setWidth(4, type: .absoluteValueType, for: .padding, edge: .maxY)
                block.backgroundColor = rowIndex == 0 ? NSColor.controlBackgroundColor : NSColor.textBackgroundColor

                let style = paragraph(spacingAfter: 0).mutableCopy() as! NSMutableParagraphStyle
                style.textBlocks = [block]
                let font = rowIndex == 0 ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
                let cell = NSMutableAttributedString(attributedString: inline(cellText, font: font, color: .labelColor))
                cell.append(NSAttributedString(string: "\n", attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
                cell.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: cell.length))
                output.append(cell)
            }
        }

        output.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paragraph(spacingAfter: 18)]))
    }

    private static func appendListItem(_ item: ListItem, to output: NSMutableAttributedString) {
        let indent = CGFloat(18 + item.indent * 22)
        let prefix = item.prefix + "  "
        let block = NSMutableAttributedString(string: prefix, attributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor])
        block.append(inline(item.text, font: .systemFont(ofSize: 14), color: .labelColor))
        block.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor]))
        block.addAttribute(.paragraphStyle, value: paragraph(spacingAfter: 5, headIndent: indent, firstLineHeadIndent: 0), range: NSRange(location: 0, length: block.length))
        output.append(block)
    }

    private static func inline(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        var index = text.startIndex
        while index < text.endIndex {
            if text[index...].hasPrefix("**"), let range = text[text.index(index, offsetBy: 2)...].range(of: "**") {
                output.append(NSAttributedString(string: String(text[text.index(index, offsetBy: 2)..<range.lowerBound]), attributes: [.font: bold(font), .foregroundColor: color]))
                index = range.upperBound
            } else if text[index...].hasPrefix("~~"), let range = text[text.index(index, offsetBy: 2)...].range(of: "~~") {
                output.append(NSAttributedString(string: String(text[text.index(index, offsetBy: 2)..<range.lowerBound]), attributes: [.font: font, .foregroundColor: color, .strikethroughStyle: NSUnderlineStyle.single.rawValue]))
                index = range.upperBound
            } else if text[index...].hasPrefix("`"), let range = text[text.index(after: index)...].range(of: "`") {
                output.append(NSAttributedString(string: String(text[text.index(after: index)..<range.lowerBound]), attributes: [.font: NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular), .foregroundColor: color, .backgroundColor: NSColor.controlBackgroundColor]))
                index = range.upperBound
            } else if text[index...].hasPrefix("["), let labelEnd = text[text.index(after: index)...].range(of: "]("), let urlEnd = text[labelEnd.upperBound...].range(of: ")") {
                output.append(NSAttributedString(string: String(text[text.index(after: index)..<labelEnd.lowerBound]), attributes: [.font: font, .foregroundColor: NSColor.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue]))
                index = urlEnd.upperBound
            } else if text[index...].hasPrefix("*"), let range = text[text.index(after: index)...].range(of: "*") {
                output.append(NSAttributedString(string: String(text[text.index(after: index)..<range.lowerBound]), attributes: [.font: italic(font), .foregroundColor: color]))
                index = range.upperBound
            } else {
                output.append(NSAttributedString(string: String(text[index]), attributes: [.font: font, .foregroundColor: color]))
                index = text.index(after: index)
            }
        }
        return output
    }

    private static func heading(from line: String) -> (text: String, size: CGFloat, before: CGFloat, after: CGFloat)? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        let text = String(line.dropFirst(level + 1))
        switch level {
        case 1: return (text, 30, 0, 20)
        case 2: return (text, 23, 24, 12)
        case 3: return (text, 19, 20, 10)
        default: return (text, 16, 16, 8)
        }
    }

    private static func listItem(from line: String) -> ListItem? {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let indent = max(0, leadingSpaces / 2)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- [x] ", "- [X] ", "* [x] ", "* [X] "] where trimmed.hasPrefix(marker) {
            return ListItem(prefix: "☑", text: String(trimmed.dropFirst(marker.count)), indent: indent)
        }
        for marker in ["- [ ] ", "* [ ] "] where trimmed.hasPrefix(marker) {
            return ListItem(prefix: "☐", text: String(trimmed.dropFirst(marker.count)), indent: indent)
        }
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            return ListItem(prefix: "•", text: String(trimmed.dropFirst(marker.count)), indent: indent)
        }
        if let range = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            return ListItem(prefix: String(trimmed[..<range.upperBound]).trimmingCharacters(in: .whitespaces), text: String(trimmed[range.upperBound...]), indent: indent)
        }
        return nil
    }

    private static func isTableLine(_ line: String) -> Bool {
        line.contains("|") && !line.hasPrefix("#")
    }

    private static func parseTable(_ lines: [String]) -> (rows: [[String]], columnCount: Int)? {
        guard lines.count >= 2 else { return nil }
        let rows = lines.map(tableCells)
        guard isSeparatorRow(rows[1]) else { return nil }

        let bodyRows = [rows[0]] + rows.dropFirst(2)
        let columnCount = bodyRows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return nil }

        let normalized = bodyRows.map { row in
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }
        return (normalized, columnCount)
    }

    private static func tableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func isSeparatorRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            let normalized = cell.replacingOccurrences(of: " ", with: "")
            guard normalized.count >= 3 else { return false }
            return normalized.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let normalized = line.replacingOccurrences(of: " ", with: "")
        return ["---", "***", "___"].contains(normalized)
    }

    private static func paragraph(spacingBefore: CGFloat = 0, spacingAfter: CGFloat = 0, lineHeightMultiple: CGFloat = 1.35, headIndent: CGFloat = 0, firstLineHeadIndent: CGFloat = 0) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = spacingBefore
        style.paragraphSpacing = spacingAfter
        style.lineHeightMultiple = lineHeightMultiple
        style.headIndent = headIndent
        style.firstLineHeadIndent = firstLineHeadIndent
        return style
    }

    private static func bold(_ font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }

    private static func italic(_ font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
}

private struct ListItem {
    let prefix: String
    let text: String
    let indent: Int
}
