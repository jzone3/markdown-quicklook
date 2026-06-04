import SwiftUI
import AppKit

@main
struct MarkdownQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Markdown QuickLook") {
            ContentView()
                .frame(minWidth: 560, idealWidth: 600, minHeight: 470, idealHeight: 510)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show as a normal windowed app and bring the window to the front so the
        // setup-confirmation screen appears when the user opens the app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
