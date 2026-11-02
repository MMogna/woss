// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import WossCore

final class GeometryTests: XCTestCase {
    // A 1440x900 screen with a 25pt menu bar: visible area in AX space starts at y=25.
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

    private func assertRect(_ r: CGRect, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(r.origin.x, x, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(r.origin.y, y, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(r.size.width, w, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(r.size.height, h, accuracy: 0.01, file: file, line: line)
    }

    func testLeftHalf() {
        assertRect(Geometry.snapFrame(RelRect(x: 0, y: 0, w: 0.5, h: 1), in: screen), 0, 25, 720, 875)
    }

    func testTopHalfSitsAtTopOfVisibleArea() {
        assertRect(Geometry.snapFrame(RelRect(x: 0, y: 0.5, w: 1, h: 0.5), in: screen), 0, 25, 1440, 437.5)
    }

    func testBottomHalfSitsAtBottom() {
        assertRect(Geometry.snapFrame(RelRect(x: 0, y: 0, w: 1, h: 0.5), in: screen), 0, 462.5, 1440, 437.5)
    }

    func testAlmostMaximize() {
        assertRect(Geometry.snapFrame(RelRect(x: 0.05, y: 0.05, w: 0.9, h: 0.9), in: screen), 72, 68.75, 1296, 787.5)
    }

    func testSecondaryScreenOffset() {
        let right = CGRect(x: 1440, y: 25, width: 1920, height: 1055)
        assertRect(Geometry.snapFrame(RelRect(x: 0.5, y: 0, w: 0.5, h: 1), in: right), 2400, 25, 960, 1055)
    }

    func testAxVisibleFrameAccountsForMenuBarNotDock() {
        // Cocoa: screen 0..900 tall, Dock 80 at bottom, menu bar 25 at top -> visible y=80,h=795
        let visible = CGRect(x: 0, y: 80, width: 1440, height: 795)
        assertRect(Geometry.axVisibleFrame(visible, desktopTop: 900), 0, 25, 1440, 795)
    }

    func testScreenIndexPicksLargestOverlap() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: -180, width: 1920, height: 1080),
        ]
        XCTAssertEqual(Geometry.screenIndex(forWindow: CGRect(x: 100, y: 100, width: 400, height: 300), screens: screens, desktopTop: 900), 0)
        XCTAssertEqual(Geometry.screenIndex(forWindow: CGRect(x: 1500, y: 100, width: 400, height: 300), screens: screens, desktopTop: 900), 1)
        // straddling: 140pt on screen 0, 260pt on screen 1
        XCTAssertEqual(Geometry.screenIndex(forWindow: CGRect(x: 1300, y: 100, width: 400, height: 300), screens: screens, desktopTop: 900), 1)
        XCTAssertNil(Geometry.screenIndex(forWindow: CGRect(x: 9000, y: 100, width: 400, height: 300), screens: screens, desktopTop: 900))
    }

    // MARK: resize

    func testDoubleWidthAnchorsLeft() {
        let r = Geometry.resizeRelative(window: CGRect(x: 100, y: 100, width: 400, height: 300), screen: screen, scaleW: 2, scaleH: 1)
        assertRect(r, 100, 100, 800, 300)
    }

    func testDoubleWidthAnchorsRight() {
        let r = Geometry.resizeRelative(window: CGRect(x: 900, y: 100, width: 400, height: 300), screen: screen, scaleW: 2, scaleH: 1)
        assertRect(r, 500, 100, 800, 300)
    }

    func testDoubleHeightAnchorsTop() {
        let r = Geometry.resizeRelative(window: CGRect(x: 100, y: 100, width: 400, height: 300), screen: screen, scaleW: 1, scaleH: 2)
        assertRect(r, 100, 100, 400, 600)
    }

    func testDoubleHeightAnchorsBottom() {
        let r = Geometry.resizeRelative(window: CGRect(x: 100, y: 600, width: 400, height: 250), screen: screen, scaleW: 1, scaleH: 2)
        assertRect(r, 100, 350, 400, 500)
    }

    func testResizeIsClampedToScreen() {
        let r = Geometry.resizeRelative(window: CGRect(x: 0, y: 25, width: 1000, height: 300), screen: screen, scaleW: 2, scaleH: 1)
        assertRect(r, 0, 25, 1440, 300)
    }

    // MARK: fit

    func testFitPullsOverflowingWindowBackOnScreen() {
        let r = Geometry.fit(CGRect(x: 1300, y: 100, width: 400, height: 300), into: screen)
        assertRect(r, 1040, 100, 400, 300)
    }

    func testFitLeavesAWindowThatAlreadyFitsAlone() {
        let w = CGRect(x: 100, y: 100, width: 400, height: 300)
        assertRect(Geometry.fit(w, into: screen), 100, 100, 400, 300)
    }

    func testFitPinsOversizedWindowToTopLeft() {
        let r = Geometry.fit(CGRect(x: 500, y: 0, width: 2000, height: 300), into: screen)
        assertRect(r, 0, 25, 2000, 300)
    }
}
