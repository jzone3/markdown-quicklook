import SwiftUI
import AppKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(radius: 10, y: 4)

            VStack(spacing: 10) {
                Text("Markdown QuickLook is set up")
                    .font(.largeTitle.bold())
                Text("Select a Markdown file in Finder and press the spacebar to preview it.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                openExamples()
            } label: {
                Label("Open Example Files", systemImage: "folder")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Text("Then press the spacebar on any example to try it.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }

    /// Copy the example Markdown files bundled inside the app to a writable
    /// folder, then reveal that folder in Finder so the user can press the
    /// spacebar on them.
    private func openExamples() {
        let fileManager = FileManager.default

        guard let bundled = Bundle.main.resourceURL?.appendingPathComponent("Examples", isDirectory: true),
              fileManager.fileExists(atPath: bundled.path) else {
            NSSound.beep()
            return
        }

        do {
            let destination = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Markdown QuickLook Examples", isDirectory: true)

            try? fileManager.removeItem(at: destination)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for item in try fileManager.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil) {
                try fileManager.copyItem(at: item, to: destination.appendingPathComponent(item.lastPathComponent))
            }

            NSWorkspace.shared.open(destination)
        } catch {
            // Fall back to revealing the read-only bundled folder.
            NSWorkspace.shared.open(bundled)
        }
    }
}
