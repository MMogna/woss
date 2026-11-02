// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import WossCore

final class CycleStateTests: XCTestCase {
    let a = WindowID(pid: 1, title: "A")
    let b = WindowID(pid: 1, title: "B")

    func testSameWindowSameKeyCycles() {
        var s = CycleState<WindowID>()
        XCTAssertEqual(s.advance(window: a, hotkey: "3", count: 3), 0)
        XCTAssertEqual(s.advance(window: a, hotkey: "3", count: 3), 1)
        XCTAssertEqual(s.advance(window: a, hotkey: "3", count: 3), 2)
        XCTAssertEqual(s.advance(window: a, hotkey: "3", count: 3), 0)
    }

    func testDifferentKeyOrWindowRestarts() {
        var s = CycleState<WindowID>()
        _ = s.advance(window: a, hotkey: "3", count: 3)
        XCTAssertEqual(s.advance(window: a, hotkey: "3", count: 3), 1)
        XCTAssertEqual(s.advance(window: a, hotkey: "4", count: 4), 0)
        XCTAssertEqual(s.advance(window: a, hotkey: "4", count: 4), 1)
        XCTAssertEqual(s.advance(window: b, hotkey: "4", count: 4), 0)
    }

    func testResetRestarts() {
        var s = CycleState<WindowID>()
        _ = s.advance(window: a, hotkey: "3", count: 3)
        _ = s.advance(window: a, hotkey: "3", count: 3)
        s.reset()
        XCTAssertEqual(s.advance(window: a, hotkey: "3", count: 3), 0)
    }

    func testSingleRectAlwaysZero() {
        var s = CycleState<WindowID>()
        XCTAssertEqual(s.advance(window: a, hotkey: "left", count: 1), 0)
        XCTAssertEqual(s.advance(window: a, hotkey: "left", count: 1), 0)
    }
}

final class KeyCodeTests: XCTestCase {
    func testKnownCodes() {
        XCTAssertEqual(KeyCodes.hotkey(forKeyCode: 123), "left")
        XCTAssertEqual(KeyCodes.hotkey(forKeyCode: 36), "enter")
        XCTAssertEqual(KeyCodes.hotkey(forKeyCode: 0), "a")
        XCTAssertEqual(KeyCodes.hotkey(forKeyCode: 39), "'")
        XCTAssertEqual(KeyCodes.keyCode(forHotkey: "3"), 20)
        XCTAssertNil(KeyCodes.hotkey(forKeyCode: 999))
    }

    func testNoDuplicateCodes() {
        XCTAssertEqual(KeyCodes.codeToHotkey.count, KeyCodes.hotkeyToCode.count)
    }

    func testRoundTrip() {
        for hk in KeyCodes.allHotkeys {
            let code = KeyCodes.keyCode(forHotkey: hk)!
            XCTAssertEqual(KeyCodes.hotkey(forKeyCode: code), hk)
        }
    }

    func testNormalizeAndDisplay() {
        XCTAssertEqual(Hotkey.normalize("  LEFT "), "left")
        XCTAssertEqual(Hotkey.normalize("R"), "r")
        XCTAssertNil(Hotkey.normalize("banana"))
        XCTAssertNil(Hotkey.normalize(""))
        XCTAssertEqual(Hotkey.display("left"), "⌃⌥←")
        XCTAssertEqual(Hotkey.display("r"), "⌃⌥R")
        XCTAssertEqual(Hotkey.display(""), "Unbound")
    }
}

final class DefaultLayoutTests: XCTestCase {
    func testCountAndHotkeysAreAllBindable() {
        XCTAssertEqual(DefaultLayouts.all.count, 45)
        for l in DefaultLayouts.all {
            XCTAssertNotNil(KeyCodes.keyCode(forHotkey: l.hotkey), "\(l.name) uses unmapped key \(l.hotkey)")
        }
    }

    func testDefaultsDoNotCollideWithActionKeys() {
        let used = Set(DefaultLayouts.all.map(\.hotkey))
        for k in ["x", "y", "d", "s", "a"] { XCTAssertFalse(used.contains(k)) }
    }
}

final class HotkeyTableTests: XCTestCase {
    func testSingleLayout() {
        let t = HotkeyTable(layouts: DefaultLayouts.all)
        XCTAssertEqual(t.action(for: "left"), .snap([RelRect(x: 0, y: 0, w: 0.5, h: 1)]))
    }

    func testCycleOrderIsPreserved() {
        let t = HotkeyTable(layouts: DefaultLayouts.all)
        guard case .snap(let rects)? = t.action(for: "3") else { return XCTFail("no cycle") }
        XCTAssertEqual(rects.map(\.x), [0, 0.333, 0.667])
        guard case .snap(let nine)? = t.action(for: "9") else { return XCTFail("no cycle") }
        XCTAssertEqual(nine.count, 9)
    }

    func testActionKeys() {
        let t = HotkeyTable(layouts: DefaultLayouts.all)
        XCTAssertEqual(t.action(for: "x"), .resize(.doubleWidth))
        XCTAssertEqual(t.action(for: "y"), .resize(.doubleHeight))
        XCTAssertEqual(t.action(for: "d"), .resize(.doubleBoth))
        XCTAssertNil(t.action(for: "z"))
    }

    func testTileKey() {
        let t = HotkeyTable(layouts: DefaultLayouts.all)
        XCTAssertEqual(t.action(for: "a"), .tileAll)
    }

    func testSwapKey() {
        let t = HotkeyTable(layouts: DefaultLayouts.all)
        XCTAssertEqual(t.action(for: "s"), .swapMode)
        let rebound = HotkeyTable(layouts: DefaultLayouts.all, keys: ActionKeys(swap: "w"))
        XCTAssertEqual(rebound.action(for: "w"), .swapMode)
        XCTAssertNil(rebound.action(for: "s"))
    }

    func testLayoutsWinOverResize() {
        let custom = [Layout(name: "Mine", x: 0, y: 0, w: 1, h: 1, hotkey: "x")]
        XCTAssertEqual(HotkeyTable(layouts: custom).action(for: "x"), .snap([RelRect(x: 0, y: 0, w: 1, h: 1)]))
    }

    func testUnboundIsIgnored() {
        let custom = [Layout(name: "Off", x: 0, y: 0, w: 1, h: 1, hotkey: "")]
        let t = HotkeyTable(layouts: custom, keys: ActionKeys(width: "", height: "y", both: "d"))
        XCTAssertNil(t.action(for: ""))
        XCTAssertNil(t.action(for: "x"))
        XCTAssertEqual(t.action(for: "y"), .resize(.doubleHeight))
    }

    func testResizeScales() {
        XCTAssertEqual(ResizeAction.doubleWidth.scaleW, 2); XCTAssertEqual(ResizeAction.doubleWidth.scaleH, 1)
        XCTAssertEqual(ResizeAction.doubleHeight.scaleW, 1); XCTAssertEqual(ResizeAction.doubleHeight.scaleH, 2)
        XCTAssertEqual(ResizeAction.doubleBoth.scaleW, 2); XCTAssertEqual(ResizeAction.doubleBoth.scaleH, 2)
    }
}

final class LayoutStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.data(using: .utf8)!.write(to: url)
    }

    func testMissingFileGivesDefaults() {
        XCTAssertEqual(LayoutStore.loadConfig(from: tempURL()), .defaults)
    }

    func testRoundTripKeepsLayoutsAndActionKeys() throws {
        let url = tempURL()
        let config = WossConfig(
            layouts: [Layout(name: "X", x: 0.25, y: 0, w: 0.5, h: 1, hotkey: "j")],
            keys: ActionKeys(width: "q", height: "", both: "d", swap: "w", tile: "m")
        )
        try LayoutStore.saveConfig(config, to: url)
        XCTAssertEqual(LayoutStore.loadConfig(from: url), config)
    }

    func testOldPythonStyleArrayStillLoads() throws {
        let url = tempURL()
        try write(#"[["Left Half", 0, 0, 0.5, 1, "left"], ["Top Half", 0, 0.5, 1, 0.5, "up"]]"#, to: url)
        let loaded = LayoutStore.loadConfig(from: url)
        XCTAssertEqual(loaded.layouts.count, 2)
        XCTAssertEqual(loaded.layouts[1], Layout(name: "Top Half", x: 0, y: 0.5, w: 1, h: 0.5, hotkey: "up"))
        XCTAssertEqual(loaded.keys, ActionKeys())
    }

    func testMissingActionEntriesFallBackToDefaults() throws {
        let url = tempURL()
        try write(#"{"layouts": [], "actions": {"swap": "w"}}"#, to: url)
        let loaded = LayoutStore.loadConfig(from: url)
        XCTAssertEqual(loaded.keys.swap, "w")
        XCTAssertEqual(loaded.keys.tile, "a")
        XCTAssertEqual(loaded.keys.width, "x")
    }

    func testMissingLayoutsFallBackToDefaults() throws {
        let url = tempURL()
        try write(#"{"actions": {"tile": "m"}}"#, to: url)
        let loaded = LayoutStore.loadConfig(from: url)
        XCTAssertEqual(loaded.layouts, DefaultLayouts.all)
        XCTAssertEqual(loaded.keys.tile, "m")
    }

    func testEmptyStringMeansUnboundAndIsKept() throws {
        let url = tempURL()
        try write(#"{"actions": {"swap": ""}}"#, to: url)
        XCTAssertEqual(LayoutStore.loadConfig(from: url).keys.swap, "")
    }

    func testSavingKeepsABackupOfThePreviousFile() throws {
        let url = tempURL()
        try write("not json at all", to: url)
        try LayoutStore.saveConfig(.defaults, to: url)
        let backup = try String(contentsOf: url.appendingPathExtension("bak"), encoding: .utf8)
        XCTAssertEqual(backup, "not json at all")
    }

    func testCorruptFileFallsBackToDefaults() throws {
        let url = tempURL()
        try write("not json", to: url)
        XCTAssertEqual(LayoutStore.loadConfig(from: url), .defaults)
    }
}
