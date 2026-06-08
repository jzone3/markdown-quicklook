import SwiftUI
import AppKit
import ServiceManagement

@main
enum MarkdownQuickLookApplication {
    private static var appDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        appDelegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility: no Dock icon, lives in the status bar.
        NSApp.setActivationPolicy(.accessory)
        registerLoginItemOnFirstLaunch()
        enableQuickLookExtensionOnFirstLaunch()
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

    private func enableQuickLookExtensionOnFirstLaunch() {
        let key = "didAttemptQuickLookExtensionEnable"
        guard !QuickLookExtensionManager.isRunningFromDiskImage else { return }
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        QuickLookExtensionManager.enable()
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

    @objc func openExtensionsSettings() {
        QuickLookExtensionManager.openExtensionsSettings()
    }

    @objc private func resetQuickLookCache() {
        QuickLookExtensionManager.resetQuickLookCache()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

}
