import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// "Tidy": arrange N windows into a neat grid. Windows keep their rough relative position
/// (top ones stay on top, left ones stay left), and a short last row is stretched to fill
/// the width, so there are never holes.
public enum Tiling {
    /// Picks columns x rows so that cells are close to a typical window shape (landscape).
    public static func gridSize(count: Int, area: CGSize, targetAspect: Double = 1.4) -> (cols: Int, rows: Int) {
        guard count > 1, area.width > 0, area.height > 0 else { return (1, 1) }

        var best = (cols: 1, rows: count)
        var bestScore = Double.greatestFiniteMagnitude
        for cols in 1...count {
            let rows = (count + cols - 1) / cols
            let cellW = Double(area.width) / Double(cols)
            let cellH = Double(area.height) / Double(rows)
            let empty = Double(cols * rows - count)
            let score = abs(log(cellW / cellH / targetAspect)) + empty * 0.1
            if score < bestScore {
                bestScore = score
                best = (cols, rows)
            }
        }
        return best
    }

    /// Number of windows in each row, top to bottom (the last row may be shorter).
    static func rowCounts(count: Int, cols: Int, rows: Int) -> [Int] {
        (0..<rows).map { r in r == rows - 1 ? count - cols * (rows - 1) : cols }
    }

    /// Grid cells in row-major order (left to right, top to bottom).
    public static func gridFrames(count: Int, in area: CGRect) -> [CGRect] {
        let (cols, rows) = gridSize(count: count, area: area.size)
        let counts = rowCounts(count: count, cols: cols, rows: rows)
        let cellH = area.height / CGFloat(rows)

        var cells: [CGRect] = []
        for (r, n) in counts.enumerated() {
            let cellW = area.width / CGFloat(n)
            for c in 0..<n {
                cells.append(CGRect(x: area.minX + CGFloat(c) * cellW,
                                    y: area.minY + CGFloat(r) * cellH,
                                    width: cellW,
                                    height: cellH))
            }
        }
        return cells
    }

    /// Target frame for every window: result[i] is where windows[i] should go.
    public static func tile(_ windows: [CGRect], in area: CGRect) -> [CGRect] {
        guard !windows.isEmpty else { return [] }
        let (cols, rows) = gridSize(count: windows.count, area: area.size)
        let counts = rowCounts(count: windows.count, cols: cols, rows: rows)
        let cells = gridFrames(count: windows.count, in: area)

        // top-to-bottom, then split into rows, then left-to-right inside each row
        let byY = windows.indices.sorted { a, b in
            let fa = windows[a], fb = windows[b]
            if fa.midY != fb.midY { return fa.midY < fb.midY }
            if fa.midX != fb.midX { return fa.midX < fb.midX }
            return a < b
        }

        var result = Array(repeating: CGRect.zero, count: windows.count)
        var start = 0
        var cell = 0
        for n in counts {
            let row = byY[start..<(start + n)].sorted { a, b in
                let xa = windows[a].midX, xb = windows[b].midX
                return xa != xb ? xa < xb : a < b
            }
            for idx in row {
                result[idx] = cells[cell]
                cell += 1
            }
            start += n
        }
        return result
    }
}
