import Foundation

/// Loads the vendored CSS / JS assets that are shipped inside the package's
/// resource bundle (`Bundle.module`).
///
/// Assets are cached after first load. If a resource cannot be found the property
/// returns an empty string so rendering still succeeds (just unstyled), which
/// keeps the renderer robust if the bundle layout ever changes.
enum BundledAsset {
    static let githubMarkdownCSS = load("github-markdown", "css")
    static let highlightLightCSS = load("highlight-github", "css")
    static let highlightDarkCSS = load("highlight-github-dark", "css")
    static let highlightJS = load("highlight.min", "js")

    private static func load(_ name: String, _ ext: String) -> String {
        let bundle = Bundle.module
        let candidateURLs: [URL?] = [
            bundle.url(forResource: name, withExtension: ext),
            bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources")
        ]
        for case let url? in candidateURLs {
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                return contents
            }
        }
        return ""
    }
}
