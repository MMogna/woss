import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import WossCore

final class TilingTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    func testGridSizes() {
        XCTAssertEqual(Tiling.gridSize(count: 1, area: area.size).cols, 1)
        let expected: [(count: Int, cols: Int, rows: Int)] = [
            (2, 2, 1), (3, 2, 2), (4, 2, 2), (5, 3, 2), (6, 3, 2), (9, 3, 3),
        ]
        for e in expected {
            let g = Tiling.gridSize(count: e.count, area: area.size)
            XCTAssertEqual(g.cols, e.cols, "cols for \(e.count)")
            XCTAssertEqual(g.rows, e.rows, "rows for \(e.count)")
        }
    }

    func testSingleWindowFillsTheArea() {
        XCTAssertEqual(Tiling.tile([CGRect(x: 10, y: 10, width: 300, height: 200)], in: area), [area])
    }

    func testShortLastRowIsStretched() {
        let cells = Tiling.gridFrames(count: 3, in: area)
        XCTAssertEqual(cells.count, 3)
        XCTAssertEqual(cells[0], CGRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertEqual(cells[1], CGRect(x: 800, y: 0, width: 800, height: 500))
        XCTAssertEqual(cells[2], CGRect(x: 0, y: 500, width: 1600, height: 500))
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

    func testThreeWindowsSideBySideBecomeTwoOverOne() {
        let w0 = CGRect(x: 0, y: 0, width: 500, height: 900)
        let w1 = CGRect(x: 500, y: 0, width: 500, height: 900)
        let w2 = CGRect(x: 1000, y: 0, width: 500, height: 900)
        let result = Tiling.tile([w0, w1, w2], in: area)
        XCTAssertEqual(result[0], CGRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertEqual(result[1], CGRect(x: 800, y: 0, width: 800, height: 500))
        XCTAssertEqual(result[2], CGRect(x: 0, y: 500, width: 1600, height: 500))
    }

    func testEmptyInput() {
        XCTAssertTrue(Tiling.tile([], in: area).isEmpty)
    }
}
