import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import WossCore

final class SwapLabelsTests: XCTestCase {
    func testAlphabet() {
        XCTAssertEqual(SwapLabels.label(at: 0), "1")
        XCTAssertEqual(SwapLabels.label(at: 8), "9")
        XCTAssertEqual(SwapLabels.label(at: 9), "a")
        XCTAssertEqual(SwapLabels.label(at: 34), "z")
        XCTAssertNil(SwapLabels.label(at: 35))
        XCTAssertEqual(SwapLabels.index(forLabel: "A"), 9)
        XCTAssertEqual(SwapLabels.index(forLabel: "3"), 2)
        XCTAssertNil(SwapLabels.index(forLabel: "-"))
    }

    func testReadingOrderOfQuadrants() {
        let tr = CGRect(x: 500, y: 0, width: 500, height: 400)   // index 0
        let bl = CGRect(x: 0, y: 400, width: 500, height: 400)   // index 1
        let tl = CGRect(x: 0, y: 0, width: 500, height: 400)     // index 2
        let br = CGRect(x: 500, y: 400, width: 500, height: 400) // index 3
        XCTAssertEqual(SwapLabels.readingOrder(of: [tr, bl, tl, br]), [2, 1, 0, 3])
    }

    func testBadgesOfSeparateWindowsStayAtCentre() {
        let a = CGRect(x: 0, y: 0, width: 400, height: 400)
        let b = CGRect(x: 500, y: 0, width: 400, height: 400)
        let centers = SwapLabels.badgeCenters(for: [a, b])
        XCTAssertEqual(centers[0], CGPoint(x: 200, y: 200))
        XCTAssertEqual(centers[1], CGPoint(x: 700, y: 200))
    }

    func testBadgesOfStackedWindowsDoNotOverlap() {
        let f = CGRect(x: 0, y: 0, width: 400, height: 400)
        let centers = SwapLabels.badgeCenters(for: [f, f, f])
        XCTAssertGreaterThanOrEqual(centers[1].y - centers[0].y, 44)
        XCTAssertGreaterThanOrEqual(centers[2].y - centers[1].y, 44)
    }
}
