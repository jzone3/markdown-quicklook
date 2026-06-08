# Research: Rendering Markdown in macOS Quick Look

This document captures the research behind **markdown-quicklook**: how macOS Quick
Look works, the modern way to extend it, the open-source projects we learned from
(and their licenses), the Markdown rendering libraries we evaluated, and the
architecture we chose.

> **Update (post-implementation):** the original plan below rendered HTML into a
> `WKWebView` inside the Quick Look extension. In practice, WebKit helper
> processes proved unreliable inside the Quick Look extension sandbox, so the
> shipped extension renders Markdown natively with AppKit
> (`NSAttributedString` + `NSTextTable` in an `NSTextView`). The
> `MarkdownRenderer` HTML pipeline described here still exists and powers the
> `mdql` CLI. The WKWebView discussion is kept as historical context.

---

## 1. How macOS Quick Look works

Quick Look is the system feature that produces the preview you see when you select
a file in Finder and press the **spacebar** (or use the column-view / Get Info
previews, Spotlight, etc.). macOS ships built-in previews for common types
(images, PDF, plain text, iWork/Office documents…). For Markdown there is **no
dedicated Markdown previewer**, so `.md` files fall back to the generic
`public.plain-text` preview — you see the raw Markdown source, not rendered
output. The goal of this project is to fill that gap.

Apps extend Quick Look by shipping an **app extension** that the system loads
on demand inside its own sandboxed process. There are two relevant Quick Look
extension points:

| Extension point | Identifier | Purpose |
| --- | --- | --- |
| **Preview** | `com.apple.quicklook.preview` | The rich view shown for the spacebar / Finder preview. Implemented with `QLPreviewingController`. |
| **Thumbnail** | `com.apple.quicklook.thumbnail` | The small thumbnail/icon shown in Finder. Implemented with `QLThumbnailProvider`. |

This project implements the **Preview** extension (the spacebar experience). A
thumbnail extension could be added later as a separate target.

### The modern API: `QLPreviewingController`

A Quick Look **Preview Extension** is an app extension embedded inside a host app.
Its principal class is an `NSViewController` (macOS) that conforms to
[`QLPreviewingController`](https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller).
The system instantiates the controller, displays its `view`, and calls one of:

- `preparePreviewOfFile(at:)` — **the one we use** (macOS 12+, `async throws`).
  The system hands us the file URL; we read it, render HTML, and load it into a
  `WKWebView`.
- `preparePreviewOfSearchableItem(identifier:queryString:)` — for Spotlight
  searchable items (not needed here; we set `QLSupportsSearchableItems = false`).

The extension is configured entirely through its `Info.plist`:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.quicklook.preview</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).PreviewViewController</string>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>QLSupportedContentTypes</key>
        <array><string>net.daringfireball.markdown</string></array>
        <key>QLSupportsSearchableItems</key><false/>
    </dict>
</dict>
```

We deliberately use `NSExtensionPrincipalClass` and build the view
programmatically instead of the storyboard (`NSExtensionMainStoryboard`) that
Xcode's template uses — it keeps the project text-only and reproducible.

### The Uniform Type Identifier (UTI) problem

For the system to route a `.md` file to our extension, the file must be tagged
with a UTI that appears in `QLSupportedContentTypes`. macOS historically has **no
system-declared Markdown UTI**, which is exactly why Markdown previews as plain
text. The de-facto identifier is **`net.daringfireball.markdown`** (after John
Gruber's original Markdown). We make this work by having the **host app declare
the type** via `UTImportedTypeDeclarations`, binding it to the `.md`, `.markdown`,
`.mdown`, … extensions and conforming it to `public.plain-text`. Installing the
app registers the type with Launch Services, after which Finder tags Markdown
files as `net.daringfireball.markdown` and our preview extension is invoked. This
is the same trick QLMarkdown and similar tools use.

We intentionally do **not** claim `public.plain-text` directly in
`QLSupportedContentTypes` — doing so would override the preview for *all* text
files, which is undesirable.

### The older, deprecated approach: `.qlgenerator` plugins

Before app extensions, Quick Look was extended with **Quick Look Generator**
plugins — `.qlgenerator` bundles (a CFPlugin implementing `GeneratePreviewForURL`
/ `GenerateThumbnailForURL`) installed into `~/Library/QuickLook` or
`/Library/QuickLook` and managed via `qlmanage`.

Why the modern Preview Extension is preferred today:

- **Quick Look Generators are deprecated.** Apple deprecated the `.qlgenerator`
  CFPlugin mechanism; new development should use Quick Look extensions.
- **Sandboxing & security.** App extensions run in their own sandboxed process
  with explicit entitlements, so a crashing or misbehaving preview can't take
  down Finder/`quicklookd` and has tightly scoped file access.
- **Distribution & lifecycle.** Extensions ship inside a normal `.app`, are
  enabled/disabled in **System Settings → Extensions**, update with the app, and
  are compatible with the Mac App Store and notarization. Free-standing
  `.qlgenerator` bundles are not.
- **Modern toolchain.** First-class Xcode target type, Swift/SwiftUI/WebKit
  support, and the `QLPreviewingController` async API.

The trade-off is that an extension must be delivered by a host app and enabled by
the user once, whereas a `.qlgenerator` was a drop-in bundle. That is an
acceptable cost for the security and longevity benefits.

---

## 2. Open-source projects studied (and their licenses)

We reviewed these projects for inspiration and to understand established patterns.
**We did not copy code from any GPL-licensed project.** Our renderer is an
original implementation; only permissively licensed assets are vendored (see
[§4](#4-licensing-summary) and `THIRD_PARTY_LICENSES.md`).

| Project | License | What we learned |
| --- | --- | --- |
| [sbarex/QLMarkdown](https://github.com/sbarex/QLMarkdown) | **GPL-3.0** | The reference, full-featured macOS Quick Look Markdown extension. Confirms the host-app-+-preview-extension model, the `net.daringfireball.markdown` UTI registration trick, cmark-gfm for parsing, and rendering to HTML shown in a web view. **Because it is GPL-3.0 we treated it as study material only and wrote our own code** to keep this project under the permissive MIT license. |
| "Spacebar / space-to-preview" tools (e.g. Peek-style utilities, [QLColorCode](https://github.com/anthonygelibert/QLColorCode), [QLStephen](https://github.com/whomwah/qlstephen)) | Mostly MIT / older `.qlgenerator` plugins | Show the broader "make spacebar preview nicer" niche and the legacy generator approach we are intentionally moving away from. Reinforced the value of syntax-highlighted, styled output. |
| [swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown) | **Apache-2.0** | Apple's official Swift Markdown parser, built on **cmark-gfm**, exposing a typed `Markup` tree with `MarkupVisitor`/`MarkupWalker`. We use this as our parser and walk the tree ourselves to emit HTML. |
| [iwasrobbed/Down](https://github.com/iwasrobbed/Down) | **MIT** (bundles cmark, BSD-2) | A popular Swift Markdown→HTML/NSAttributedString library wrapping cmark. Great ergonomics (`Down(...).toHTML()`), but its bundled cmark is **not** GitHub-flavored, so GFM tables/strikethrough/task-lists don't render. That limitation pushed us toward swift-markdown (cmark-**gfm**). |
| [sindresorhus/github-markdown-css](https://github.com/sindresorhus/github-markdown-css) | **MIT** | The well-known stylesheet that makes rendered Markdown look like GitHub, with built-in light/dark via `prefers-color-scheme`. Vendored as our theme. |
| [highlightjs/highlight.js](https://github.com/highlightjs/highlight.js) | **BSD-3-Clause** | Client-side syntax highlighter with a matching GitHub theme. Vendored (highlighter + light/dark themes) and inlined into the rendered HTML for code-block highlighting. |

---

## 3. Markdown rendering options evaluated

| Option | GFM (tables, task lists)? | Pros | Cons | Verdict |
| --- | --- | --- | --- | --- |
| **swift-markdown** (cmark-gfm) + custom HTML walker | ✅ | Apple-maintained, pure SwiftPM, **builds on Linux** (so the core is CI-testable), typed tree, no C interop to wire up in the Xcode project | Must write our own `Markup`→HTML conversion | **Chosen** |
| **Down** (cmark) | ❌ (no GFM) | Tiny API, `toHTML()` out of the box | Not GitHub-flavored; vendors C sources | Rejected (no tables) |
| **cmark-gfm directly** (C) | ✅ | Canonical GFM, fastest | C interop, module maps, build complexity in an app extension | Rejected for v1 (complexity) |
| Native `AttributedString(markdown:)` / SwiftUI `Text` | partial | No deps | Limited block support (no real tables/code styling), hard to theme like GitHub | Rejected |

### Why "render to HTML + WKWebView" instead of native rendering

- A `WKWebView` + `github-markdown-css` gives an instantly familiar, **GitHub-like
  look** with correct handling of headings, code blocks, tables, blockquotes,
  images, and links — far more than `NSAttributedString` supports.
- HTML/CSS makes **light/dark** trivial via `prefers-color-scheme`.
- **highlight.js** drops in for syntax highlighting without reimplementing a
  tokenizer per language.

---

## 4. Licensing summary

This project is **MIT**. We respect every upstream license:

- **swift-markdown** — Apache-2.0. Consumed as an unmodified SwiftPM dependency.
- **github-markdown-css** — MIT. Vendored stylesheet.
- **highlight.js** (+ GitHub light/dark themes) — BSD-3-Clause. Vendored.
- **QLMarkdown** — GPL-3.0. **Studied only; no code copied.** Keeping our own code
  original is what lets this project stay MIT instead of being forced to GPL.

Full upstream license texts and exact versions are recorded in
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).

---

## 5. Chosen architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Host app  (MarkdownQuickLook.app, SwiftUI)                    │
│  • Registers the net.daringfireball.markdown UTI (Info.plist) │
│  • Onboarding UI: how to enable the extension                 │
│  • Live in-app preview (same renderer) for sanity-checking    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Embedded app extension (QuickLookExtension.appex)       │  │
│  │  • NSExtensionPointIdentifier = quicklook.preview       │  │
│  │  • PreviewViewController : QLPreviewingController        │  │
│  │  • preparePreviewOfFile(at:) → render → WKWebView        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                 │ both targets depend on
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ MarkdownRenderer (SwiftPM library, platform-independent)      │
│  • Document(parsing:) via swift-markdown (cmark-gfm)          │
│  • HTMLMarkupVisitor: Markup tree → GitHub-flavored HTML      │
│  • Inlines github-markdown-css + highlight.js into one        │
│    self-contained HTML document                               │
│  • No AppKit/WebKit → builds & unit-tests on Linux CI         │
└─────────────────────────────────────────────────────────────┘
```

Key decisions:

- **Shared, UI-free rendering core.** All Markdown→HTML logic lives in the
  `MarkdownRenderer` SwiftPM library with **no** AppKit/WebKit imports, so it
  compiles and is unit-tested on Linux as well as macOS. The macOS targets are
  thin `WKWebView` wrappers. (This repo's tests run green on Linux Swift 5.10.)
- **Self-contained HTML.** The renderer inlines all CSS/JS into a single HTML
  string, so the sandboxed extension needs **no network and no extra file
  access** — it just calls `WKWebView.loadHTMLString(_:baseURL:)`.
- **Security-first defaults.** Raw HTML embedded in a `.md` file is **escaped by
  default** (`allowsRawHTML == false`), so a malicious document can't inject
  `<script>` into the preview. `javascript:`/`vbscript:` URLs in links/images are
  neutralized. JavaScript stays enabled only so our trusted, inlined highlight.js
  can run.
- **Reproducible project.** The Xcode project is generated from a committed
  `project.yml` via **XcodeGen**; the `.xcodeproj` is git-ignored. The package
  also exposes a small `mdql` CLI that uses the exact same rendering path
  (handy for testing and CI smoke checks).

### Supported Markdown features (v1)

Headings (with anchor IDs) · paragraphs · **bold** / *italic* / ~~strikethrough~~
· inline `code` · fenced code blocks with syntax highlighting · ordered /
unordered / nested lists · GitHub task lists · blockquotes · thematic breaks ·
links · images · **GFM tables with column alignment** · automatic light/dark
appearance.

### Known limitations / future work

- Remote images require network access (off by default for sandbox safety);
  local sibling images depend on the sandbox granting directory access.
- No thumbnail extension yet (`QLThumbnailProvider`) — preview only.
- App icon is a placeholder.
- Optional future settings (toggle raw-HTML passthrough, theme choice,
  Mermaid/math) are not implemented in v1.
