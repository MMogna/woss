// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import WossCore

final class TilingTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    // MARK: plans

    func testPlansOnALandscapeScreen() {
        let expected: [(count: Int, axis: Tiling.Axis, counts: [Int])] = [
            (1, .rows, [1]),
            (2, .rows, [2]),
            (3, .columns, [2, 1]),
            (4, .rows, [2, 2]),
            (5, .rows, [3, 2]),
            (6, .rows, [3, 3]),
            (7, .columns, [3, 2, 2]),
            (8, .columns, [3, 3, 2]),
            (9, .rows, [3, 3, 3]),
            (10, .rows, [4, 3, 3]),
        ]
        for e in expected {
            let p = Tiling.plan(count: e.count, area: area.size)
            XCTAssertEqual(p.axis, e.axis, "axis for \(e.count)")
            XCTAssertEqual(p.counts, e.counts, "counts for \(e.count)")
        }
    }

    func testSevenWindowsHaveNoLoneStretchedWindow() {
        let cells = Tiling.gridFrames(count: 7, in: area)
        XCTAssertEqual(cells.count, 7)
        XCTAssertTrue(cells.allSatisfy { $0.width < 600 }, "no cell should span more than a third of the width")
        let areas = cells.map { $0.width * $0.height }
        XCTAssertLessThan(areas.max()! / areas.min()!, 1.6)
    }

    func testThreeWindowsOnAnUltrawideScreenStaySideBySide() {
        let p = Tiling.plan(count: 3, area: CGSize(width: 3440, height: 1440))
        XCTAssertEqual(p.axis, .rows)
        XCTAssertEqual(p.counts, [3])
    }

    func testBalancedCounts() {
        XCTAssertEqual(Tiling.balancedCounts(total: 7, lines: 3), [3, 2, 2])
        XCTAssertEqual(Tiling.balancedCounts(total: 8, lines: 3), [3, 3, 2])
        XCTAssertEqual(Tiling.balancedCounts(total: 6, lines: 2), [3, 3])
    }

    // MARK: cells always tile the area, whatever the count and screen shape

    func testCellsCoverTheAreaExactlyAndNeverOverlap() {
        let sizes = [
            CGSize(width: 1600, height: 1000), CGSize(width: 1920, height: 1080),
            CGSize(width: 1000, height: 1600), CGSize(width: 3440, height: 1440),
        ]
        for size in sizes {
            let box = CGRect(origin: CGPoint(x: 20, y: 40), size: size)
            for n in 1...16 {
                let windows = (0..<n).map { CGRect(x: CGFloat($0) * 50, y: 0, width: 40, height: 40) }
                let cells = Tiling.tile(windows, in: box)
                XCTAssertEqual(cells.count, n)

                let total = cells.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
                XCTAssertEqual(total, box.width * box.height, accuracy: 1, "area for n=\(n), \(size)")

                let slack = box.insetBy(dx: -0.01, dy: -0.01)
                for i in 0..<n {
                    XCTAssertTrue(slack.contains(cells[i]), "cell \(i) outside the area for n=\(n)")
                    for j in (i + 1)..<n {
                        let overlap = cells[i].intersection(cells[j])
                        XCTAssertTrue(overlap.isNull || overlap.width * overlap.height < 1,
                                      "cells \(i) and \(j) overlap for n=\(n)")
                    }
                }
            }
        }
    }

    // MARK: assignment

    func testSingleWindowFillsTheArea() {
        XCTAssertEqual(Tiling.tile([CGRect(x: 10, y: 10, width: 300, height: 200)], in: area), [area])
    }

    func testEmptyInput() {
        XCTAssertTrue(Tiling.tile([], in: area).isEmpty)
    }

    func testWindowsKeepTheirRelativePositions() {
        let a = CGRect(x: 0, y: 0, width: 300, height: 300)      // top-left
        let b = CGRect(x: 600, y: 0, width: 300, height: 300)    // top-right
        let c = CGRect(x: 0, y: 500, width: 300, height: 300)    // bottom-left
        let d = CGRect(x: 600, y: 500, width: 300, height: 300)  // bottom-right
        let box = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let result = Tiling.tile([d, b, a, c], in: box)
        XCTAssertEqual(result[0], CGRect(x: 500, y: 400, width: 500, height: 400)) // d
        XCTAssertEqual(result[1], CGRect(x: 500, y: 0, width: 500, height: 400))   // b
        XCTAssertEqual(result[2], CGRect(x: 0, y: 0, width: 500, height: 400))     // a
        XCTAssertEqual(result[3], CGRect(x: 0, y: 400, width: 500, height: 400))   // c
    }

    func testThreeWindowsBecomeTwoStackedBesideOneTall() {
        let w0 = CGRect(x: 0, y: 0, width: 500, height: 900)
        let w1 = CGRect(x: 500, y: 0, width: 500, height: 900)
        let w2 = CGRect(x: 1000, y: 0, width: 500, height: 900)
        let result = Tiling.tile([w0, w1, w2], in: area)
        XCTAssertEqual(result[0], CGRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertEqual(result[1], CGRect(x: 0, y: 500, width: 800, height: 500))
        XCTAssertEqual(result[2], CGRect(x: 800, y: 0, width: 800, height: 1000))
    }
}
