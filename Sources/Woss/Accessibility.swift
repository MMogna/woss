import ApplicationServices

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system "grant Accessibility access" prompt (once) if not yet trusted.
    @discardableResult
    static func promptIfNeeded() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
