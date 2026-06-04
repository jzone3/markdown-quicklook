# AGENTS.md

This repo builds a macOS Quick Look preview extension for Markdown files.

## What matters

- Default branch: `master`.
- Generate the Xcode project with `xcodegen generate`; do not commit generated `.xcodeproj` files.
- The Quick Look extension is in `QuickLookExtension/`.
- The host app is in `App/`.
- The reusable Swift package / HTML renderer is in `Sources/MarkdownRenderer/`.
- The command-line renderer is `Sources/mdql/`.
- Tests live in `Tests/MarkdownRendererTests/`.

## Website / landing page (important)

The public landing page at https://quicklookmd.com is **not** part of `master`.

- `master` is kept clean as the open-source, buildable project. It contains no
  website source. Do **not** add a `docs/` folder or a Pages-deploy workflow back
  to `master`.
- The landing page (`index.html`, `styles.css`, `assets/`, `CNAME`, `favicon.png`)
  lives only on the [`gh-pages`](https://github.com/jzone3/markdown-quicklook/tree/gh-pages)
  branch. GitHub Pages serves that branch directly (Settings → Pages →
  Source = "Deploy from a branch: gh-pages"), which is why the `CNAME` for the
  custom domain lives there.
- To change the website, edit and commit on the `gh-pages` branch. Changes go
  live on push — there is no separate build step and nothing to mirror.

## Install guidance

For end-user install work, follow `agent-instructions/INSTALL.md`. Prefer asking Devin or another coding agent to run those steps because local signing, extension registration, and Quick Look cache resets are easy to get wrong manually.

## Build and test

```bash
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen generate
swift test
```

For the macOS app/extension build, a local Apple Development certificate is usually needed:

```bash
xcodebuild \
  -project MarkdownQuickLook.xcodeproj \
  -scheme MarkdownQuickLook \
  -configuration Debug \
  -derivedDataPath .derivedData-signed \
  build
```

If signing fails, set a Team manually on both `MarkdownQuickLook` and `QuickLookExtension` in Xcode.

## Implementation notes

- The Quick Look extension renders Markdown to native AppKit attributed text in `NSTextView`.
- Tables use native `NSTextTable` / `NSTextTableBlock` cells.
- The extension intentionally avoids `WKWebView`; WebKit helper processes can crash or be denied sandbox permissions inside Quick Look extensions.
- The Swift package still supports rendering Markdown to self-contained HTML for the host app and `mdql` CLI.

## Do not commit

- `.derivedData*/`
- `.build/`
- `.swiftpm/`
- generated `.xcodeproj`
- local `test-files/`
