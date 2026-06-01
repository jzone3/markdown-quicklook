import Foundation
import MarkdownRenderer

// Tiny command-line helper that converts Markdown to a self-contained HTML
// document. Handy for local testing / CI smoke tests and shares the exact same
// rendering path as the macOS Quick Look extension.
//
// Usage:
//   mdql <input.md> [output.html]   # render a file
//   mdql                            # read Markdown from stdin, write HTML to stdout

let arguments = Array(CommandLine.arguments.dropFirst())

let markdown: String
var title = "Markdown Preview"

if let inputPath = arguments.first {
    guard let contents = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
        FileHandle.standardError.write(Data("mdql: could not read \(inputPath)\n".utf8))
        exit(1)
    }
    markdown = contents
    title = (inputPath as NSString).lastPathComponent
} else {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    markdown = String(data: data, encoding: .utf8) ?? ""
}

let html = MarkdownRenderer.renderFullHTMLDocument(from: markdown, title: title)

if arguments.count >= 2 {
    let outputPath = arguments[1]
    do {
        try html.write(toFile: outputPath, atomically: true, encoding: .utf8)
    } catch {
        FileHandle.standardError.write(Data("mdql: could not write \(outputPath): \(error)\n".utf8))
        exit(1)
    }
} else {
    print(html)
}
