import SwiftUI
import AppKit

struct ContentView: View {
    @State private var extensionState: QuickLookExtensionManager.State = .checking
    @State private var isEnabling = false

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(radius: 10, y: 4)

            VStack(spacing: 10) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                if !needsInstall && extensionState != .enabled {
                    Button {
                        enableExtension()
                    } label: {
                        Label(isEnabling ? "Enabling…" : "Enable Quick Look", systemImage: "checkmark.circle")
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(isEnabling)

                    Button {
                        QuickLookExtensionManager.openExtensionsSettings()
                    } label: {
                        Label("Open Extensions Settings", systemImage: "gearshape")
                    }
                    .controlSize(.large)
                }

                Button {
                    Examples.open()
                } label: {
                    Label("Open Example Files", systemImage: "folder")
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
            }

            Text(footer)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Markdown QuickLook lives in your menu bar and starts automatically at login.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .onAppear {
            refreshState()
        }
    }

    private var title: String {
        if needsInstall {
            return "Drag Markdown QuickLook to Applications"
        }
        switch extensionState {
        case .checking:
            return "Checking Markdown QuickLook"
        case .enabled:
            return "Markdown QuickLook is set up"
        case .disabled:
            return "Turn on Markdown QuickLook"
        case .notRegistered:
            return "Finish installing Markdown QuickLook"
        case .unknown:
            return "Check Markdown QuickLook"
        }
    }

    private var subtitle: String {
        if needsInstall {
            return "Install the app before enabling its Quick Look extension."
        }
        switch extensionState {
        case .checking:
            return "Checking whether the Quick Look extension is enabled."
        case .enabled:
            return "Select a Markdown file in Finder and press the spacebar to preview it."
        case .disabled:
            return "The app is installed, but macOS has Quick Look switched off."
        case .notRegistered:
            return "The bundled Quick Look extension is not registered with macOS yet."
        case .unknown:
            return "macOS returned an unexpected Quick Look extension state."
        }
    }

    private var footer: String {
        if needsInstall {
            return "Close this window, drag MarkdownQuickLook to Applications, then open it from Applications."
        }
        switch extensionState {
        case .enabled:
            return "Creates an examples folder in your Downloads — press the spacebar on any file to preview it."
        case .disabled:
            return "If macOS still shows Quick Look off, click the info button next to MarkdownQuickLook in Extensions Settings and turn on Quick Look."
        case .notRegistered:
            return "If this app is still on the disk image, drag it to Applications first, then open it from Applications."
        default:
            return "Creates an examples folder in your Downloads — press the spacebar on any file to preview it."
        }
    }

    private var needsInstall: Bool {
        QuickLookExtensionManager.isRunningFromDiskImage
    }

    private func refreshState() {
        DispatchQueue.global(qos: .userInitiated).async {
            let state = QuickLookExtensionManager.status()
            DispatchQueue.main.async {
                extensionState = state
            }
        }
    }

    private func enableExtension() {
        isEnabling = true
        DispatchQueue.global(qos: .userInitiated).async {
            let state = QuickLookExtensionManager.enable()
            DispatchQueue.main.async {
                extensionState = state
                isEnabling = false
            }
        }
    }
}
