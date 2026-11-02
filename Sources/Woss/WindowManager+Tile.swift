// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import WossCore

extension WindowManager {
    /// "Tidy": arranges all visible windows into a grid, one grid per screen
    /// (each window belongs to the screen it overlaps the most).
    func tileAll() {
        let windows = swappableWindows()
        guard !windows.isEmpty else {
            NSSound.beep()
            return
        }

        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        let desktopTop = primary.frame.maxY
        let screenFrames = screens.map(\.frame)

        var groups: [Int: [SwapCandidate]] = [:]
        for w in windows {
            let index = Geometry.screenIndex(forWindow: w.frame, screens: screenFrames, desktopTop: desktopTop) ?? 0
            groups[index, default: []].append(w)
        }

        for (index, group) in groups {
            let area = Geometry.axVisibleFrame(screens[index].visibleFrame, desktopTop: desktopTop)
            let targets = Tiling.tile(group.map(\.frame), in: area)
            for (i, w) in group.enumerated() {
                applyFrame(targets[i], to: w.element)
            }
        }
        resetCycle() // windows moved under any running loop
    }
}
