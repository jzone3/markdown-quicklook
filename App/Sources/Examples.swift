import AppKit

/// Deploys the example Markdown files that ship inside the app bundle to a
/// writable folder and reveals it in Finder, so the user can press the spacebar
/// on them. Shared by the setup window's button and the menu-bar menu.
enum Examples {
    static func open() {
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
