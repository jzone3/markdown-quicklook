import XCTest
@testable import MarkdownRenderer

final class MarkdownRendererTests: XCTestCase {

    private func fragment(_ markdown: String, allowsRawHTML: Bool = false) -> String {
        MarkdownRenderer.renderHTMLFragment(
            from: markdown,
            options: MarkdownRenderingOptions(allowsRawHTML: allowsRawHTML)
        )
    }

    // MARK: - Block elements

    func testHeadingsRenderWithLevelsAndSlugIDs() {
        let html = fragment("# Hello World\n\n## Sub Section")
        XCTAssertTrue(html.contains("<h1 id=\"hello-world\">"), html)
        XCTAssertTrue(html.contains("<h2 id=\"sub-section\">"), html)
        XCTAssertTrue(html.contains("Hello World"))
    }

    func testDuplicateHeadingSlugsAreDeduplicated() {
        let html = fragment("# Title\n\n# Title")
        XCTAssertTrue(html.contains("id=\"title\""), html)
        XCTAssertTrue(html.contains("id=\"title-1\""), html)
    }

    func testParagraphAndInlineFormatting() {
        let html = fragment("This is **bold**, *italic*, ~~struck~~ and `code`.")
        XCTAssertTrue(html.contains("<strong>bold</strong>"), html)
        XCTAssertTrue(html.contains("<em>italic</em>"), html)
        XCTAssertTrue(html.contains("<del>struck</del>"), html)
        XCTAssertTrue(html.contains("<code>code</code>"), html)
    }

    func testFencedCodeBlockGetsLanguageClass() {
        let html = fragment("```swift\nlet x = 1\n```")
        XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">"), html)
        XCTAssertTrue(html.contains("let x = 1"))
    }

    func testCodeBlockContentsAreEscaped() {
        let html = fragment("```\n<script>alert(1)</script>\n```")
        XCTAssertTrue(html.contains("&lt;script&gt;"), html)
        XCTAssertFalse(html.contains("<script>alert(1)</script>"), html)
    }

    func testUnorderedAndOrderedLists() {
        let ul = fragment("- a\n- b")
        XCTAssertTrue(ul.contains("<ul>"), ul)
        XCTAssertTrue(ul.contains("<li>a</li>"), ul)

        let ol = fragment("3. first\n4. second")
        XCTAssertTrue(ol.contains("<ol start=\"3\">"), ol)
    }

    func testTaskListCheckboxes() {
        let html = fragment("- [x] done\n- [ ] todo")
        XCTAssertTrue(html.contains("class=\"task-list-item\""), html)
        XCTAssertTrue(html.contains("checked"), html)
    }

    func testBlockquote() {
        let html = fragment("> quoted")
        XCTAssertTrue(html.contains("<blockquote>"), html)
        XCTAssertTrue(html.contains("quoted"))
    }

    func testThematicBreak() {
        XCTAssertTrue(fragment("a\n\n---\n\nb").contains("<hr />"))
    }

    func testGFMTableWithAlignment() {
        let md = """
        | Left | Center | Right |
        | :--- | :----: | ----: |
        | a | b | c |
        """
        let html = fragment(md)
        XCTAssertTrue(html.contains("<table>"), html)
        XCTAssertTrue(html.contains("<th align=\"left\">Left</th>"), html)
        XCTAssertTrue(html.contains("<th align=\"center\">Center</th>"), html)
        XCTAssertTrue(html.contains("<th align=\"right\">Right</th>"), html)
        XCTAssertTrue(html.contains("<td align=\"center\">b</td>"), html)
    }

    // MARK: - Links & images

    func testLinkRendering() {
        let html = fragment("[Devin](https://devin.ai)")
        XCTAssertTrue(html.contains("<a href=\"https://devin.ai\">Devin</a>"), html)
    }

    func testImageRendering() {
        let html = fragment("![alt text](image.png \"a title\")")
        XCTAssertTrue(html.contains("<img src=\"image.png\""), html)
        XCTAssertTrue(html.contains("alt=\"alt text\""), html)
        XCTAssertTrue(html.contains("title=\"a title\""), html)
    }

    func testJavascriptURLIsNeutralized() {
        let html = fragment("[click](javascript:alert(1))")
        XCTAssertFalse(html.lowercased().contains("javascript:"), html)
        XCTAssertTrue(html.contains("href=\"#\""), html)
    }

    // MARK: - Raw HTML handling

    func testRawHTMLEscapedByDefault() {
        let html = fragment("<script>alert(1)</script>")
        XCTAssertFalse(html.contains("<script>alert(1)</script>"), html)
        XCTAssertTrue(html.contains("&lt;script&gt;"), html)
    }

    func testRawHTMLPassthroughWhenEnabled() {
        let html = fragment("<div class=\"x\">hi</div>", allowsRawHTML: true)
        XCTAssertTrue(html.contains("<div class=\"x\">"), html)
    }

    func testTextSpecialCharactersEscaped() {
        let html = fragment("a < b & c > d")
        XCTAssertTrue(html.contains("a &lt; b &amp; c &gt; d"), html)
    }

    // MARK: - Full document & bundled assets

    func testFullDocumentIsSelfContained() {
        let html = MarkdownRenderer.renderFullHTMLDocument(from: "# Title", title: "T")
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"), String(html.prefix(40)))
        XCTAssertTrue(html.contains("class=\"markdown-body\""), html)
        XCTAssertTrue(html.contains("<title>T</title>"), html)
    }

    func testBundledAssetsAreLoaded() {
        XCTAssertFalse(BundledAsset.githubMarkdownCSS.isEmpty, "github-markdown.css missing from bundle")
        XCTAssertFalse(BundledAsset.highlightJS.isEmpty, "highlight.min.js missing from bundle")
        XCTAssertFalse(BundledAsset.highlightLightCSS.isEmpty, "highlight light theme missing")
        XCTAssertFalse(BundledAsset.highlightDarkCSS.isEmpty, "highlight dark theme missing")
    }

    func testFullDocumentEmbedsHighlightAssetsWhenEnabled() {
        let html = MarkdownRenderer.renderFullHTMLDocument(from: "```swift\nlet x = 1\n```")
        XCTAssertTrue(html.contains("hljs"), "highlight.js should be embedded")
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"), html)
    }
}
