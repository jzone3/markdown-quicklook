import SwiftUI
import AppKit

struct ContentView: View {
    var body: some View {
        HSplitView {
            instructions
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
            MarkdownWebView(markdown: ContentView.demoMarkdown)
                .frame(minWidth: 380)
        }
    }

    private var instructions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Markdown QuickLook")
                    .font(.largeTitle.bold())
                Text("Press the spacebar on a Markdown file in Finder to see it rendered as styled HTML instead of plain text.")
                    .foregroundStyle(.secondary)

                Divider()

                Text("Enable the extension")
                    .font(.headline)
                stepsList

                Button {
                    openExtensionsSettings()
                } label: {
                    Label("Open Extensions Settings", systemImage: "gearshape")
                }
                .controlSize(.large)

                Divider()

                Text("If a preview doesn't update, run `qlmanage -r` in Terminal to reset the Quick Look cache, or log out and back in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "Build and run this app once so macOS registers the extension.")
            step(2, "Open System Settings → General → Login Items & Extensions → Quick Look (on macOS 13–14: System Settings → Privacy & Security → Extensions → Quick Look).")
            step(3, "Turn on “Markdown Preview”.")
            step(4, "Select any .md file in Finder and press the spacebar.")
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.callout.monospacedDigit().bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openExtensionsSettings() {
        // Opens the Extensions pane in System Settings.
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.preference.security?Extensions"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static let demoMarkdown = """
    # Markdown QuickLook

    This is a **live preview** rendered by the same engine the Quick Look
    extension uses.

    ## Features

    - GitHub-flavored Markdown (tables, task lists, strikethrough)
    - Syntax-highlighted code blocks
    - Automatic light / dark appearance

    ```swift
    func greet(_ name: String) -> String {
        return "Hello, \\(name)!"
    }
    ```

    | Element | Supported |
    | :------ | :-------: |
    | Tables  |    yes    |
    | Images  |    yes    |

    > Press the spacebar on a `.md` file in Finder to try it for real.
    """
}
