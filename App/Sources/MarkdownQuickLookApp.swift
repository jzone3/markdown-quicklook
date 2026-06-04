import SwiftUI
import AppKit
import ServiceManagement

@main
struct MarkdownQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI is driven entirely by the AppDelegate (a menu-bar status item
        // plus a setup window), so this scene is just a required placeholder.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility: no Dock icon, lives in the status bar.
        NSApp.setActivationPolicy(.accessory)
        registerLoginItemOnFirstLaunch()
        setUpStatusItem()
        showMainWindow()
    }

    /// Start the app automatically at login. Only registered on first launch so
    /// a user who later turns it off in System Settings stays opted out.
    private func registerLoginItemOnFirstLaunch() {
        let key = "didRegisterLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // Re-open the setup window if the user launches the app again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // MARK: - Status bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Markdown QuickLook")
        item.button?.imagePosition = .imageLeading
        item.button?.title = "Markdown"
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Example Files", action: #selector(openExamples), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Markdown QuickLook", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Extensions Settings", action: #selector(openExtensionsSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Quick Look Cache", action: #selector(resetQuickLookCache), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Markdown QuickLook", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    // MARK: - Window

    private func showMainWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: ContentView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "Markdown QuickLook"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.setContentSize(NSSize(width: 600, height: 510))
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc private func openExamples() {
        Examples.open()
    }

    @objc private func showWindow() {
        showMainWindow()
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
