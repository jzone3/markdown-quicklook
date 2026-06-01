import Foundation

enum HTMLEscaping {
    /// Escapes text for safe inclusion in HTML element content.
    static func escapeText(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            default: result.append(character)
            }
        }
        return result
    }

    /// Escapes a string for safe inclusion inside a double-quoted HTML attribute.
    static func escapeAttribute(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    /// Conservatively validates a URL used in `href`/`src` attributes.
    ///
    /// Blocks `javascript:`, `vbscript:` and similar script-bearing schemes to
    /// avoid script execution from untrusted Markdown. Relative URLs, anchors,
    /// and the common safe schemes are allowed.
    static func sanitizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let blockedSchemes = ["javascript:", "vbscript:", "data:text/html"]
        for scheme in blockedSchemes where lowered.hasPrefix(scheme) {
            return "#"
        }
        return trimmed
    }
}
