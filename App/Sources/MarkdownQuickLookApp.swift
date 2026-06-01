import SwiftUI
import AppKit

@main
struct MarkdownQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ContentView()
                .frame(minWidth: 760, minHeight: 580)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Markdown QuickLook")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = "Markdown"
        statusItem.menu = menu()
        self.statusItem = statusItem
    }

    private func menu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Extensions Settings", action: #selector(openExtensionsSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Quick Look Cache", action: #selector(resetQuickLookCache), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Markdown QuickLook", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func openExtensionsSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.preference.security?Extensions"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @objc private func resetQuickLookCache() {
        run("/usr/bin/qlmanage", ["-r"])
        run("/usr/bin/qlmanage", ["-r", "cache"])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func run(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try? process.run()
    }
}
