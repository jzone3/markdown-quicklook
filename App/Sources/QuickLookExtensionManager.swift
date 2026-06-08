import AppKit
import Foundation

enum QuickLookExtensionManager {
    enum State: Equatable {
        case checking
        case enabled
        case disabled
        case notRegistered
        case unknown
    }

    private static let identifier = "com.devin.markdownquicklook.QuickLookExtension"

    static var isRunningFromDiskImage: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Volumes/")
    }

    static func status() -> State {
        let output = run("/usr/bin/pluginkit", ["-m", "-A", "-D", "-i", identifier])
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains(identifier) }

        guard !lines.isEmpty else { return .notRegistered }
        if lines.contains(where: { $0.hasPrefix("+") || $0.hasPrefix("!") }) { return .enabled }
        if lines.contains(where: { $0.hasPrefix("-") }) { return .disabled }
        return .unknown
    }

    @discardableResult
    static func enable() -> State {
        guard !isRunningFromDiskImage else { return status() }
        registerBundledExtension()
        _ = run("/usr/bin/pluginkit", ["-e", "use", "-i", identifier])
        resetQuickLookCache()
        return status()
    }

    static func resetQuickLookCache() {
        _ = run("/usr/bin/qlmanage", ["-r"])
        _ = run("/usr/bin/qlmanage", ["-r", "cache"])
    }

    static func openExtensionsSettings() {
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

    private static func registerBundledExtension() {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("QuickLookExtension.appex") else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        _ = run("/usr/bin/pluginkit", ["-a", url.path])
    }

    @discardableResult
    private static func run(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
