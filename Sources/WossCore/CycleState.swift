import Foundation

/// Identity of a window: owning app pid + title (same approach as the Python version).
public struct WindowID: Equatable {
    public var pid: Int32
    public var title: String
    public init(pid: Int32, title: String) {
        self.pid = pid
        self.title = title
    }
}

/// Remembers which step of a cycle we're on, so pressing the same hotkey on the same
/// window again advances to the next rectangle; anything else restarts at step 0.
public struct CycleState {
    private var last: (window: WindowID, hotkey: String)?
    private var step = 0

    public init() {}

    public mutating func advance(window: WindowID, hotkey: String, count: Int) -> Int {
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
