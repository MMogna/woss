// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// "Tidy": arrange N windows into a neat grid.
///
/// The grid is either ROWS (each row split into equal cells) or COLUMNS (each column split
/// into equal cells), with line sizes as even as possible (7 windows -> 3, 2, 2). Every
/// candidate is scored and the best one wins:
///
///   score = average distance of each cell's shape from a typical window shape
///         + 0.5 * ln(largest cell area / smallest cell area)
///
/// The first term avoids tall slivers and flat strips, the second avoids a layout where one
/// window gets twice (or ten times) the space of its neighbours. Because both axes are tried,
/// landscape screens naturally pick columns when that gives rounder cells, and portrait or
/// ultrawide screens adapt on their own.
public enum Tiling {
    public enum Axis: Equatable {
        case rows     // lines run top to bottom, windows sit side by side inside a line
        case columns  // lines run left to right, windows are stacked inside a line
    }

    public struct Plan: Equatable {
        public var axis: Axis
        /// Windows per line, in order (top to bottom for rows, left to right for columns).
        public var counts: [Int]
        public var score: Double
    }

    /// Width / height of a "typical" window.
    static let targetAspect = 1.4
    /// How strongly unequal cell sizes are punished.
    static let uniformityWeight = 0.5

    // MARK: planning

    public static func plan(count: Int, area: CGSize) -> Plan {
        guard count > 1, area.width > 0, area.height > 0 else {
            return Plan(axis: .rows, counts: [max(count, 1)], score: 0)
        }

        var best: Plan?
        for axis in [Axis.rows, Axis.columns] {
            for lines in 1...count {
                let counts = balancedCounts(total: count, lines: lines)
                let s = score(axis: axis, counts: counts, area: area)
                // strict "less than" with a tolerance: on a tie the earlier (rows, fewer lines) stays
                if best == nil || s < best!.score - 1e-9 {
                    best = Plan(axis: axis, counts: counts, score: s)
                }
            }
        }
        return best!
    }

    /// 7 windows in 3 lines -> [3, 2, 2]: sizes differ by at most one, larger lines first.
    static func balancedCounts(total: Int, lines: Int) -> [Int] {
        let base = total / lines
        let extra = total % lines
        return (0..<lines).map { base + ($0 < extra ? 1 : 0) }
    }

    /// Width and height of one cell, for a line holding `inLine` windows.
    private static func cellSize(axis: Axis, inLine: Int, lines: Int, area: CGSize) -> (w: Double, h: Double) {
        let w = Double(area.width)
        let h = Double(area.height)
        switch axis {
        case .rows: return (w / Double(inLine), h / Double(lines))
        case .columns: return (w / Double(lines), h / Double(inLine))
        }
    }

    private static func score(axis: Axis, counts: [Int], area: CGSize) -> Double {
        var shapeSum = 0.0
        var total = 0
        var smallest = Double.greatestFiniteMagnitude
        var largest = 0.0

        for c in counts {
            let cell = cellSize(axis: axis, inLine: c, lines: counts.count, area: area)
            shapeSum += Double(c) * abs(log(cell.w / cell.h / targetAspect))
            total += c
            smallest = min(smallest, cell.w * cell.h)
            largest = max(largest, cell.w * cell.h)
        }
        return shapeSum / Double(total) + uniformityWeight * log(largest / smallest)
    }

    // MARK: cells

    /// The cells of a plan, line by line (and inside a line left to right / top to bottom).
    public static func cells(for plan: Plan, in area: CGRect) -> [CGRect] {
        var result: [CGRect] = []
        for (i, c) in plan.counts.enumerated() {
            let cell = cellSize(axis: plan.axis, inLine: c, lines: plan.counts.count, area: area.size)
            let cw = CGFloat(cell.w)
            let ch = CGFloat(cell.h)
            for j in 0..<c {
                switch plan.axis {
                case .rows:
                    result.append(CGRect(x: area.minX + CGFloat(j) * cw, y: area.minY + CGFloat(i) * ch,
                                         width: cw, height: ch))
                case .columns:
                    result.append(CGRect(x: area.minX + CGFloat(i) * cw, y: area.minY + CGFloat(j) * ch,
                                         width: cw, height: ch))
                }
            }
        }
        return result
    }

    public static func gridFrames(count: Int, in area: CGRect) -> [CGRect] {
        cells(for: plan(count: count, area: area.size), in: area)
    }

    // MARK: assignment

    /// Target frame for every window: result[i] is where windows[i] should go.
    /// Windows keep their rough relative position: they are ordered along the lines'
    /// direction, cut into lines, and ordered again inside each line.
    public static func tile(_ windows: [CGRect], in area: CGRect) -> [CGRect] {
        guard !windows.isEmpty else { return [] }

        let layout = Tiling.plan(count: windows.count, area: area.size)
        let frames = Tiling.cells(for: layout, in: area)

        func lineKey(_ f: CGRect) -> CGFloat { layout.axis == .rows ? f.midY : f.midX }
        func inLineKey(_ f: CGRect) -> CGFloat { layout.axis == .rows ? f.midX : f.midY }

        let ordered = windows.indices.sorted { a, b in
            let ka = lineKey(windows[a])
            let kb = lineKey(windows[b])
            if ka != kb { return ka < kb }
            let ia = inLineKey(windows[a])
            let ib = inLineKey(windows[b])
            if ia != ib { return ia < ib }
            return a < b
        }

        var result = Array(repeating: CGRect.zero, count: windows.count)
        var start = 0
        var cell = 0
        for c in layout.counts {
            let line = ordered[start..<(start + c)].sorted { a, b in
                let ia = inLineKey(windows[a])
                let ib = inLineKey(windows[b])
                return ia != ib ? ia < ib : a < b
            }
            for index in line {
                result[index] = frames[cell]
                cell += 1
            }
            start += c
        }
        return result
    }
}
