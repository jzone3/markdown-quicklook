// swift-tools-version:5.9
import PackageDescription

// MarkdownQuickLook shared rendering core.
//
// This package contains ONLY the platform-independent Markdown -> HTML rendering
// logic. It deliberately avoids any AppKit / WebKit / QuickLook imports so it can
// be built and unit-tested on Linux CI as well as macOS. The macOS host app and
// the Quick Look Preview Extension (defined in the Xcode project, see project.yml)
// link against the `MarkdownRenderer` product and only add the thin WKWebView glue.
let package = Package(
    name: "MarkdownQuickLook",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MarkdownRenderer",
            targets: ["MarkdownRenderer"]
        ),
        .executable(
            name: "mdql",
            targets: ["mdql"]
        )
    ],
    dependencies: [
        // Apache-2.0. GitHub-flavored Markdown parser (built on cmark-gfm).
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "MarkdownRenderer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .copy("Resources/github-markdown.css"),
                .copy("Resources/highlight-github.css"),
                .copy("Resources/highlight-github-dark.css"),
                .copy("Resources/highlight.min.js")
            ]
        ),
        .executableTarget(
            name: "mdql",
            dependencies: ["MarkdownRenderer"]
        ),
        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: ["MarkdownRenderer"]
        )
    ]
)
