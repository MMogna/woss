// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public enum ResizeAction: Equatable {
    case doubleWidth
    case doubleHeight
    case doubleBoth

    public var scaleW: Double { self == .doubleHeight ? 1 : 2 }
    public var scaleH: Double { self == .doubleWidth ? 1 : 2 }
}

/// Hotkeys for the non-layout actions. An empty string means "unbound".
/// Stored in config.json under "actions"; missing entries fall back to the defaults.
public struct ActionKeys: Equatable, Codable {
    public var width: String
    public var height: String
    public var both: String
    public var swap: String
    public var tile: String

    public init(width: String = "x", height: String = "y", both: String = "d",
                swap: String = "s", tile: String = "a") {
        self.width = width
        self.height = height
        self.both = both
        self.swap = swap
        self.tile = tile
    }

    private enum CodingKeys: String, CodingKey {
        case width = "doubleWidth"
        case height = "doubleHeight"
        case both = "doubleSize"
        case swap
        case tile
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(String.self, forKey: .width) ?? "x"
        height = try c.decodeIfPresent(String.self, forKey: .height) ?? "y"
        both = try c.decodeIfPresent(String.self, forKey: .both) ?? "d"
        swap = try c.decodeIfPresent(String.self, forKey: .swap) ?? "s"
        tile = try c.decodeIfPresent(String.self, forKey: .tile) ?? "a"
    }
}

public enum HotkeyAction: Equatable {
    case snap([RelRect])      // ordered loop of target rectangles
    case resize(ResizeAction)
    case swapMode             // label every window, then pick two to swap
    case tileAll              // arrange all visible windows into a neat grid
}

/// Lookup from a hotkey string to what it should do. Layouts win over the other actions.
public struct HotkeyTable {
    private var cycles: [String: [RelRect]] = [:]
    private var tools: [String: HotkeyAction] = [:]

    public init(layouts: [Layout], keys: ActionKeys = ActionKeys()) {
        for l in layouts {
            guard let hk = Hotkey.normalize(l.hotkey) else { continue }
            cycles[hk, default: []].append(l.rect)
        }
        let entries: [(String, HotkeyAction)] = [
            (keys.width, .resize(.doubleWidth)),
            (keys.height, .resize(.doubleHeight)),
            (keys.both, .resize(.doubleBoth)),
            (keys.swap, .swapMode),
            (keys.tile, .tileAll),
        ]
        for (key, action) in entries {
            if let hk = Hotkey.normalize(key) { tools[hk] = action }
        }
    }

    public func action(for hotkey: String) -> HotkeyAction? {
        if let rects = cycles[hotkey], !rects.isEmpty { return .snap(rects) }
        return tools[hotkey]
    }
}
