import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Pure helpers for "swap windows" mode: which label each window gets, in what order,
/// and where its badge sits. All frames are in the same (AX / top-left origin) space.
public enum SwapLabels {
    /// 1-9, then a-z: up to 35 windows.
    public static let alphabet: [String] =
        (1...9).map { String($0) } + "abcdefghijklmnopqrstuvwxyz".map { String($0) }

    public static func label(at index: Int) -> String? {
        alphabet.indices.contains(index) ? alphabet[index] : nil
    }

    public static func index(forLabel label: String) -> Int? {
        alphabet.firstIndex(of: label.lowercased())
    }

    /// Spatial order: columns left to right (100pt buckets), top to bottom inside a column.
    /// Labels stay stable as long as windows don't move, unlike a "most recently used" order.
    public static func readingOrder(of frames: [CGRect]) -> [Int] {
        func column(_ f: CGRect) -> Int { Int((f.midX / 100).rounded(.down)) }
        return frames.indices.sorted { a, b in
            let ca = column(frames[a])
            let cb = column(frames[b])
            if ca != cb { return ca < cb }
            let ya = frames[a].midY
            let yb = frames[b].midY
            if ya != yb { return ya < yb }
            return a < b
        }
    }

    /// Badge centre for each frame: the window's centre, nudged downward while it would
    /// collide with a badge that was already placed (e.g. stacked / cascaded windows).
    public static func badgeCenters(for frames: [CGRect], badgeSize: CGFloat = 44) -> [CGPoint] {
        var placed: [CGPoint] = []
        for f in frames {
            var c = CGPoint(x: f.midX, y: f.midY)
            var tries = 0
            while tries < 12 && placed.contains(where: { abs($0.x - c.x) < badgeSize && abs($0.y - c.y) < badgeSize }) {
                c.y += badgeSize + 4
                tries += 1
            }
            placed.append(c)
        }
        return placed
    }
}
