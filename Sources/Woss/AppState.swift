import Foundation
import WossCore

/// The app's current settings.
final class AppState {
    private(set) var layouts: [Layout] = []
    private(set) var keys = ActionKeys()

    /// Called whenever settings change, so the hotkey table can be rebuilt.
    var onChange: (() -> Void)?

    var table: HotkeyTable { HotkeyTable(layouts: layouts, keys: keys) }

    func reloadFromDisk() {
        let config = LayoutStore.loadConfig()
        layouts = config.layouts
        keys = config.keys
        onChange?()
    }

    /// Called by the preferences window on "Save & Close". Saves everything to config.json.
    func apply(layouts: [Layout], keys: ActionKeys) {
        self.layouts = layouts
        self.keys = keys
        do {
            try LayoutStore.saveConfig(WossConfig(layouts: layouts, keys: keys))
        } catch {
            print("⚠️ could not save config: \(error)")
        }
        onChange?()
    }
}
