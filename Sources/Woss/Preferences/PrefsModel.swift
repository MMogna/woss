import Foundation
import WossCore

/// One row in the settings window = one hotkey, i.e. one LOOP of layouts.
/// (e.g. the three vertical thirds share the "3" key: pressing it repeatedly steps
/// through left → center → right, so they appear as a single row.)
struct LayoutRow: Identifiable {
    let id: String            // the default hotkey of this group; stable across rebinding
    var title: String
    var section: String
    var layouts: [Layout]
    var hotkey: String        // "" = unbound

    var rects: [RelRect] { layouts.map(\.rect) }
    var isLoop: Bool { layouts.count > 1 }
    var stepNames: String { layouts.map(\.name).joined(separator: "  →  ") }
}

final class PrefsModel: ObservableObject {
    @Published var layoutRows: [LayoutRow]
    @Published var keys: ActionKeys

    /// Display order of the sections.
    static let sections = [
        "Halves", "Maximize", "Thirds & Quarters", "Corners", "Sixths, Eighths & Ninths", "Other",
    ]

    /// Section + short name for each default hotkey group.
    private static let meta: [String: (section: String, title: String)] = [
        "left": ("Halves", "Left Half"),
        "right": ("Halves", "Right Half"),
        "up": ("Halves", "Top Half"),
        "down": ("Halves", "Bottom Half"),
        "enter": ("Maximize", "Fullscreen"),
        "'": ("Maximize", "Almost Maximize"),
        "3": ("Thirds & Quarters", "Vertical Thirds"),
        "t": ("Thirds & Quarters", "Horizontal Thirds"),
        "4": ("Thirds & Quarters", "Vertical Quarters"),
        "e": ("Thirds & Quarters", "Three-Quarters"),
        "u": ("Corners", "Top-Left Corner"),
        "i": ("Corners", "Top-Right Corner"),
        "j": ("Corners", "Bottom-Left Corner"),
        "k": ("Corners", "Bottom-Right Corner"),
        "r": ("Sixths, Eighths & Ninths", "Sixths"),
        "8": ("Sixths, Eighths & Ninths", "Eighths"),
        "9": ("Sixths, Eighths & Ninths", "Ninths"),
    ]

    init(layouts: [Layout], keys: ActionKeys) {
        self.layoutRows = PrefsModel.rows(from: layouts)
        self.keys = keys
    }

    func indices(in section: String) -> [Int] {
        layoutRows.indices.filter { layoutRows[$0].section == section }
    }

    /// Rows follow the default layout order. Current bindings/geometry come from `current`;
    /// a group with no layouts in `current` was unbound, so it shows as "Unbound".
    static func rows(from current: [Layout]) -> [LayoutRow] {
        var order: [String] = []
        var groups: [String: [Layout]] = [:]
        for d in DefaultLayouts.all {
            if groups[d.hotkey] == nil { order.append(d.hotkey) }
            groups[d.hotkey, default: []].append(d)
        }
        return order.map { key in
            let defaults = groups[key]!
            let names = Set(defaults.map(\.name))
            let present = current.filter { names.contains($0.name) }
            let layouts = present.isEmpty ? defaults : present
            let hotkey = present.isEmpty ? "" : present[0].hotkey

            let info = meta[key]
            let title = info?.title ?? layouts.map(\.name).joined(separator: " / ")
            let section = info?.section ?? "Other"
            return LayoutRow(id: key, title: title, section: section, layouts: layouts, hotkey: hotkey)
        }
    }

    func resetDefaults() {
        layoutRows = PrefsModel.rows(from: DefaultLayouts.all)
        keys = ActionKeys()
    }

    /// Bound rows -> flat layout list for config.json. Rows rebound to the same key
    /// end up adjacent, forming one loop.
    func flattenedLayouts() -> [Layout] {
        var order: [String] = []
        var byKey: [String: [Layout]] = [:]
        for row in layoutRows where !row.hotkey.isEmpty {
            if byKey[row.hotkey] == nil { order.append(row.hotkey) }
            for var l in row.layouts {
                l.hotkey = row.hotkey
                byKey[row.hotkey, default: []].append(l)
            }
        }
        return order.flatMap { byKey[$0]! }
    }
}
