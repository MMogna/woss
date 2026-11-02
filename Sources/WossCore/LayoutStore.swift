// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Everything that is saved in config.json.
public struct WossConfig: Equatable {
    public var layouts: [Layout]
    public var keys: ActionKeys

    public init(layouts: [Layout], keys: ActionKeys) {
        self.layouts = layouts
        self.keys = keys
    }

    public static var defaults: WossConfig {
        WossConfig(layouts: DefaultLayouts.all, keys: ActionKeys())
    }
}

/// Loads/saves ~/.config/woss/config.json.
///
/// Current format:   { "layouts": [ [name, x, y, w, h, hotkey], ... ],
///                     "actions": { "doubleWidth": "x", "swap": "s", "tile": "a", ... } }
/// The old format (a bare array of layouts, as written by the Python Gridshift) is still read.
public enum LayoutStore {
    public static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("woss", isDirectory: true)
    }

    public static var configURL: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    private struct ConfigFile: Codable {
        var layouts: [Layout]?
        var actions: ActionKeys?
    }

    /// Missing or unreadable file -> defaults.
    public static func loadConfig(from url: URL = LayoutStore.configURL) -> WossConfig {
        guard let data = try? Data(contentsOf: url) else { return .defaults }
        let decoder = JSONDecoder()

        if let file = try? decoder.decode(ConfigFile.self, from: data) {
            return WossConfig(layouts: file.layouts ?? DefaultLayouts.all,
                              keys: file.actions ?? ActionKeys())
        }
        if let legacy = try? decoder.decode([Layout].self, from: data) {
            return WossConfig(layouts: legacy, keys: ActionKeys())
        }
        return .defaults
    }

    public static func saveConfig(_ config: WossConfig, to url: URL = LayoutStore.configURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // If the old file was unreadable we silently loaded defaults; keep the previous
        // version next to it so a save can never destroy someone's hand-edited config.
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = ConfigFile(layouts: config.layouts, actions: config.keys)
        try encoder.encode(file).write(to: url, options: .atomic)
    }
}
