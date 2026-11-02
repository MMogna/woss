// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// macOS virtual keycodes (US layout) <-> the hotkey strings used in config.json.
public enum KeyCodes {
    static let special: [String: Int] = [
        "left": 123, "right": 124, "down": 125, "up": 126, "space": 49, "enter": 36,
    ]

    static let chars: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "'": 39, ",": 43, ".": 47, "/": 44, ";": 41, "[": 33, "]": 30, "\\": 42, "-": 27,
        "=": 24, "`": 50,
    ]

    static let hotkeyToCode: [String: Int] = special.merging(chars) { a, _ in a }

    static let codeToHotkey: [Int: String] = {
        var m: [Int: String] = [:]
        for (name, code) in hotkeyToCode { m[code] = name }
        return m
    }()

    public static func hotkey(forKeyCode code: Int) -> String? { codeToHotkey[code] }
    public static func keyCode(forHotkey hotkey: String) -> Int? { hotkeyToCode[hotkey] }
    public static var allHotkeys: [String] { Array(hotkeyToCode.keys) }
}

public enum Hotkey {
    /// Same rule as the Python matcher: trimmed + lowercased, and valid only if it is a
    /// named special key (left, enter, ...) or a single character. Returns nil otherwise.
    public static func normalize(_ raw: String) -> String? {
        let hk = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if KeyCodes.special[hk] != nil || hk.count == 1 { return hk }
        return nil
    }

    /// 'left' -> '⌃⌥←', 'r' -> '⌃⌥R', '' -> 'Unbound'
    public static func display(_ hotkey: String) -> String {
        if hotkey.isEmpty { return "Unbound" }
        let symbols = ["left": "←", "right": "→", "up": "↑", "down": "↓", "space": "Space", "enter": "↵"]
        return "⌃⌥" + (symbols[hotkey] ?? hotkey.uppercased())
    }
}
