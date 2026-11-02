// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Carbon.HIToolbox
import WossCore

/// What a physical key prints on the CURRENT keyboard layout (Italian, German, AZERTY...).
/// Shortcuts are stored by key position; this is only used to show them correctly.
enum KeyLabels {
    /// The character on the key, or nil if it can't be determined (then callers fall back
    /// to the US name).
    static func character(forHotkey hotkey: String) -> String? {
        guard let code = KeyCodes.keyCode(forHotkey: hotkey) else { return nil }
        return character(forKeyCode: code)
    }

    /// Text for a swap badge: the key's character on this layout, upper-cased.
    static func display(forHotkey hotkey: String) -> String {
        (character(forHotkey: hotkey) ?? hotkey).uppercased()
    }

    static func character(forKeyCode keyCode: Int) -> String? {
        for source in candidateSources() {
            if let text = translate(keyCode: keyCode, source: source) { return text }
        }
        return nil
    }

    /// The current layout first; if it has no character data (e.g. a Japanese input method),
    /// the most recent ASCII-capable layout.
    private static func candidateSources() -> [TISInputSource] {
        var sources: [TISInputSource] = []
        if let current = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() {
            sources.append(current)
        }
        if let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() {
            sources.append(ascii)
        }
        return sources
    }

    private static func translate(keyCode: Int, source: TISInputSource) -> String? {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }
        let layout = UnsafeRawPointer(bytes).bindMemory(to: UCKeyboardLayout.self, capacity: 1)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,                              // no modifiers: the plain, unshifted key
            UInt32(LMGetKbdType()),
            OptionBits(1),                  // bit 0 = kUCKeyTranslateNoDeadKeysBit
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        guard status == noErr, length > 0 else { return nil }

        let text = String(utf16CodeUnits: chars, count: length)
        guard let first = text.unicodeScalars.first, first.value > 32 else { return nil } // skip control chars
        return text
    }
}
