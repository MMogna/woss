// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import WossCore

/// The "swap windows" mode:  hotkey → badges appear → press label A → press label B → swapped.
/// Esc, the hotkey again, or 8 seconds without input cancels.
final class SwapController {
    private let windowManager: WindowManager
    private let overlay = SwapOverlay()
    private var windows: [SwapCandidate] = []
    private var firstIndex: Int?
    private var timeoutTimer: Timer?

    /// While active, the hotkey listener swallows ALL keystrokes and forwards them here.
    private(set) var isActive = false {
        didSet { onActiveChanged?(isActive) }
    }
    var onActiveChanged: ((Bool) -> Void)?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func toggle() {
        if isActive { end() } else { begin() }
    }

    private func begin() {
        let found = windowManager.swappableWindows()
        guard found.count >= 2 else {
            NSSound.beep() // nothing to swap
            return
        }

        let order = SwapLabels.readingOrder(of: found.map(\.frame))
        windows = Array(order.map { found[$0] }.prefix(SwapLabels.alphabet.count))

        let centers = SwapLabels.badgeCenters(for: windows.map(\.frame))
        let labels = windows.indices.compactMap { SwapLabels.label(at: $0) }
        overlay.show(labels: labels, centers: centers)

        firstIndex = nil
        isActive = true
        restartTimeout()
    }

    func handleKey(keyCode: Int, hasHotkeyModifiers: Bool, swapKey: String) {
        guard isActive else { return }

        if keyCode == 53 { // Esc
            end()
            return
        }
        guard let key = KeyCodes.hotkey(forKeyCode: keyCode), key.count == 1 else {
            restartTimeout()
            return
        }
        if hasHotkeyModifiers && key == swapKey { // pressed the swap hotkey again
            end()
            return
        }
        guard let index = SwapLabels.index(forLabel: key), index < windows.count else {
            restartTimeout()
            return
        }

        if let first = firstIndex {
            if first == index { // same label twice = undo the first pick
                firstIndex = nil
                overlay.select(nil)
                restartTimeout()
                return
            }
            windowManager.swapWindows(windows[first], windows[index])
            end()
        } else {
            firstIndex = index
            overlay.select(index)
            restartTimeout()
        }
    }

    /// Safe to call at any time (also when swap mode isn't active).
    func end() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        overlay.hide()
        windows = []
        firstIndex = nil
        isActive = false
    }

    private func restartTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.end()
        }
    }
}
