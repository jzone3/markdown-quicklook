# Markdown QuickLook — Sample

A demo document showing how **markdown-quicklook** renders Markdown when you press
the **spacebar** on a `.md` file in Finder.

## Text formatting

You can write **bold**, *italic*, ~~strikethrough~~, and `inline code`. Combine
them for ***bold italic*** when needed. Here is a [link to Apple's Quick Look
docs](https://developer.apple.com/documentation/quicklook).

> Blockquotes are great for callouts.
>
> They can span multiple paragraphs.

## Lists

- Espresso
- Cortado
  - With oat milk
  - With whole milk
- Pour over

1. Grind beans
2. Boil water
3. Brew

### Task list

- [x] Parse Markdown
- [x] Render to HTML
- [ ] Ship to the App Store

## Code with syntax highlighting

```swift
import QuickLookUI

final class PreviewViewController: NSViewController, QLPreviewingController {
    func preparePreviewOfFile(at url: URL) async throws {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let html = MarkdownRenderer.renderFullHTMLDocument(from: markdown)
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}
```

```python
def fib(n: int) -> int:
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

## Tables

| Feature           | Status | Notes                       |
| :---------------- | :----: | --------------------------: |
| Headings          |   ✅   |                  h1 – h6    |
| Code highlighting |   ✅   |              highlight.js   |
| Tables            |   ✅   |     GitHub-flavored (GFM)   |

## Images

![A small placeholder](https://via.placeholder.com/120x40.png?text=img)

---

That's it — a quick tour of the supported Markdown features.
