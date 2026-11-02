// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// A plain value usable as a window identity in tests (pid + title).
/// The app itself does NOT identify windows this way: titles change when a window is
/// moved/resized (Terminal shows its size in the title, browsers show the page), which
/// used to reset loops halfway. The app uses the window's Accessibility element instead.
public struct WindowID: Equatable {
    public var pid: Int32
    public var title: String
    public init(pid: Int32, title: String) {
        self.pid = pid
        self.title = title
    }
}

/// Remembers which step of a loop we're on, so pressing the same hotkey on the same
/// window again advances to the next rectangle; anything else restarts at step 0.
public struct CycleState<Window: Equatable> {
    private var last: (window: Window, hotkey: String)?
    private var step = 0

    public init() {}

    public mutating func advance(window: Window, hotkey: String, count: Int) -> Int {
        if let last, last.window == window, last.hotkey == hotkey, count > 0 {
            step = (step + 1) % count
        } else {
            step = 0
        }
        last = (window, hotkey)
        return step
    }

    public mutating func reset() {
        last = nil
        step = 0
    }
}
