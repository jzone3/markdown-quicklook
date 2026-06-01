# Markdown QuickLook

Press the **spacebar** on a Markdown file in Finder and see it **rendered** —
headings, tables, code with syntax highlighting, task lists, the works — instead
of raw text.

macOS Quick Look shows `.md` files as plain text out of the box. **Markdown
QuickLook** is a small, open-source [Quick Look Preview Extension](https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller)
that renders Markdown to clean, GitHub-styled HTML (light **and** dark mode) right
in the spacebar preview.

![Rendered Markdown preview — headings, lists, task list](docs/screenshot-light.png)
![Rendered Markdown preview — syntax-highlighted code and a GFM table](docs/screenshot-code-table.png)

> [!IMPORTANT]
> **Build status / honesty note.** This project was authored on Linux, where the
> macOS app and Quick Look extension **cannot be compiled, signed, or run**. The
> platform-independent rendering core (`MarkdownRenderer`) **is** built and unit-
> tested on Linux (Swift 5.10, all tests green) and the Xcode project is generated
> and structurally validated with XcodeGen. The macOS-specific WKWebView/Quick
> Look glue has **not** been compiled yet — you need to open it in Xcode on a Mac,
> set a signing team, build, and enable the extension. See
> [Build & install](#build--install). If something doesn't compile, please open an
> issue.

---

## Features

- **GitHub-flavored Markdown** via Apple's [swift-markdown](https://github.com/swiftlang/swift-markdown)
  (cmark-gfm): headings, **bold**/*italic*/~~strike~~, inline & fenced code,
  ordered/unordered/nested lists, **task lists**, blockquotes, thematic breaks,
  links, images, and **GFM tables with column alignment**.
- **Syntax highlighting** for code blocks via [highlight.js](https://github.com/highlightjs/highlight.js).
- **GitHub look** via [github-markdown-css](https://github.com/sindresorhus/github-markdown-css),
  with automatic **light / dark** appearance.
- **Self-contained & sandbox-friendly:** all CSS/JS is inlined into the rendered
  HTML, so the extension needs **no network access**.
- **Security-first:** raw HTML in a `.md` file is escaped by default (no
  `<script>` injection); `javascript:` URLs are neutralized.
- **Shared, testable core:** the renderer is a UI-free Swift package that builds
  and is unit-tested on Linux and macOS. Includes a tiny `mdql` CLI.

---

## Requirements

- macOS 12 (Monterey) or later
- Xcode 14 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to
  generate the Xcode project from `project.yml`

---

## Build & install

```bash
git clone https://github.com/jzone3/markdown-quicklook.git
cd markdown-quicklook

# 1) Generate the Xcode project from the committed spec
brew install xcodegen        # if you don't have it
xcodegen generate

# 2) Open it
open MarkdownQuickLook.xcodeproj
```

In Xcode:

1. Select the **MarkdownQuickLook** scheme.
2. Open the **MarkdownQuickLook** target → **Signing & Capabilities** and set your
   **Team** (a free personal Apple ID works for local use; pick "Sign to Run
   Locally" if you have no team). Do the same for the **QuickLookExtension**
   target. The bundle identifiers default to `com.example.markdownquicklook(.QuickLookExtension)` —
   change the prefix to your own (e.g. `com.yourname.…`).
3. **Build & Run** (⌘R) once. Running the app registers the Markdown file type and
   the extension with the system.

> Prefer the command line? `xcodebuild -project MarkdownQuickLook.xcodeproj -scheme MarkdownQuickLook -configuration Release build`

### Enable the extension

Quick Look extensions must be turned on once:

- **macOS 15 (Sequoia):** System Settings → **General → Login Items & Extensions**
  → **Quick Look** → enable **Markdown Preview**.
- **macOS 13–14 (Ventura/Sonoma):** System Settings → **Privacy & Security →
  Extensions → Quick Look** → enable **Markdown Preview**.
- **macOS 12 (Monterey):** System Preferences → **Extensions → Quick Look** →
  enable **Markdown Preview**.

The app has an **"Open Extensions Settings"** button to take you there.

### Try it

Select any `.md`/`.markdown` file in Finder and press **spacebar**.

If the preview doesn't update (Quick Look caches aggressively):

```bash
qlmanage -r            # reset Quick Look
qlmanage -r cache
# As a last resort, log out and back in.
```

You can also test a specific file from Terminal:

```bash
qlmanage -p path/to/file.md
```

---

## How it works

```
Finder (spacebar)
   └─▶ QuickLookExtension.appex  (NSExtensionPointIdentifier = com.apple.quicklook.preview)
          └─▶ PreviewViewController : QLPreviewingController
                 └─▶ MarkdownRenderer.renderFullHTMLDocument(from:)   ← shared SwiftPM library
                        • swift-markdown (cmark-gfm) parses Markdown → Markup tree
                        • HTMLMarkupVisitor walks the tree → GitHub-flavored HTML
                        • inlines github-markdown-css + highlight.js
                 └─▶ WKWebView.loadHTMLString(...)
```

The host app declares the `net.daringfireball.markdown` UTI (`App/Info.plist`) and
binds it to the common Markdown extensions, so Finder routes those files to the
extension. See [`RESEARCH.md`](RESEARCH.md) for the full design, the modern
Preview-Extension vs. legacy `.qlgenerator` comparison, the OSS projects studied,
and licensing.

### Repository layout

```
markdown-quicklook/
├── Package.swift                 # SwiftPM: MarkdownRenderer library + mdql CLI + tests
├── project.yml                   # XcodeGen spec → macOS app + Quick Look extension
├── Sources/
│   ├── MarkdownRenderer/         # UI-free Markdown→HTML core (Linux + macOS)
│   │   ├── MarkdownRenderer.swift
│   │   ├── HTMLMarkupVisitor.swift
│   │   ├── HTMLEscaping.swift
│   │   ├── BundledAsset.swift
│   │   └── Resources/            # github-markdown-css, highlight.js (+themes)
│   └── mdql/                     # tiny CLI that uses the same renderer
├── Tests/MarkdownRendererTests/  # XCTest suite (runs on Linux)
├── App/                          # SwiftUI host app (sources, Info.plist, entitlements)
├── QuickLookExtension/           # QLPreviewingController, Info.plist, entitlements
├── Examples/sample.md            # demo document
├── docs/                         # screenshots
├── RESEARCH.md                   # research write-up
└── THIRD_PARTY_LICENSES.md
```

---

## Develop & test the rendering core (no Mac required)

The renderer is a normal Swift package; build and test it anywhere:

```bash
swift build
swift test

# Render a file to a self-contained HTML document with the CLI:
swift run mdql Examples/sample.md preview.html
# ...then open preview.html in any browser.
```

---

## Contributing

Contributions welcome! Good first issues: a real app icon, a thumbnail extension
(`QLThumbnailProvider`), settings (raw-HTML passthrough, theme choice), Mermaid /
math support, and broader UTI coverage.

- Keep the **rendering core UI-free** so it stays Linux-testable; put any
  AppKit/WebKit code in the app/extension targets.
- Add/keep **unit tests** for renderer changes (`swift test`).
- Regenerate the project with `xcodegen generate` after editing `project.yml`
  (don't commit the generated `.xcodeproj`).
- Respect third-party licenses; don't copy GPL code (see
  [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md)).

---

## License

[MIT](LICENSE). Bundled assets and dependencies retain their own permissive
licenses — see [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).
