// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import WossCore

/// The app's current settings.
final class AppState {
    private(set) var layouts: [Layout] = []
    private(set) var keys = ActionKeys()
    private(set) var gap = 0

    /// Called whenever settings change, so the hotkey table can be rebuilt.
    var onChange: (() -> Void)?

    var table: HotkeyTable { HotkeyTable(layouts: layouts, keys: keys) }

    func reloadFromDisk() {
        let config = LayoutStore.loadConfig()
        layouts = config.layouts
        keys = config.keys
        gap = config.gap
        onChange?()
    }

    /// Called by the preferences window on "Save & Close". Saves everything to config.json.
    func apply(layouts: [Layout], keys: ActionKeys, gap: Int) {
        self.layouts = layouts
        self.keys = keys
        self.gap = gap
        do {
            try LayoutStore.saveConfig(WossConfig(layouts: layouts, keys: keys, gap: gap))
        } catch {
            print("⚠️ could not save config: \(error)")
        }
        onChange?()
    }
}
