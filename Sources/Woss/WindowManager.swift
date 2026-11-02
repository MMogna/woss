// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
import WossCore

/// A window, compared by the identity of its Accessibility element — NOT by its title.
/// Titles change when a window is moved or resized (Terminal puts its size in the title,
/// browsers put the page there), which used to restart loops halfway through.
struct WindowRef: Equatable {
    let element: AXUIElement

    static func == (lhs: WindowRef, rhs: WindowRef) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}

/// Type-checked casts for Accessibility values (no force-casting of unknown CF types).
func asAXElement(_ value: AnyObject?) -> AXUIElement? {
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

func asAXValue(_ value: AnyObject?) -> AXValue? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    return (value as! AXValue)
}

/// Talks to other apps' windows through the Accessibility API.
/// Everything here must run on the main thread.
final class WindowManager {
    private var cycle = CycleState<WindowRef>()

    init() {
        // Without this, a frozen app can block an Accessibility call for 6 seconds, freezing
        // Woss's menus and windows for that long. (The key listener has its own thread, so
        // the keyboard itself is never held up.)
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
    }

    func resetCycle() {
        cycle.reset()
    }

    // MARK: - actions

    /// Hotkey press: advances through `rects` if the same key is pressed again on the same window.
    func snapStep(rects: [RelRect], hotkey: String) {
        guard !rects.isEmpty, let element = focusedWindow() else { return }

        let step = cycle.advance(window: WindowRef(element: element), hotkey: hotkey, count: rects.count)
        let screen = screenFrameAX(forWindowFrame: frame(of: element))
        let target = Geometry.snapFrame(rects[step], in: screen)
        applyFrame(target, to: element)

        // A window with a minimum size may refuse to shrink to the target and end up hanging
        // off the screen edge. Pull it back in (position only, never resize).
        if let actual = frame(of: element) {
            let fitted = Geometry.fit(actual, into: screen)
            if fitted.origin != actual.origin {
                setPosition(fitted.origin, of: element)
            }
        }
    }

    func resize(_ action: ResizeAction) {
        guard let element = focusedWindow(), let current = frame(of: element) else { return }
        let screen = screenFrameAX(forWindowFrame: current)
        let target = Geometry.resizeRelative(window: current, screen: screen,
                                             scaleW: action.scaleW, scaleH: action.scaleH)
        applyFrame(target, to: element)
        cycle.reset() // geometry changed under the loop, start fresh next time
    }

    // MARK: - Accessibility helpers

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success else {
            return nil
        }
        return asAXElement(value)
    }

    func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posValue = asAXValue(posRef),
              let sizeValue = asAXValue(sizeRef)
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: point, size: size)
    }

    func setPosition(_ origin: CGPoint, of window: AXUIElement) {
        var point = origin
        if let pv = AXValueCreate(.cgPoint, &point) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        }
    }

    /// Visible area (no menu bar / Dock) of the screen the window is mostly on, in AX coordinates.
    private func screenFrameAX(forWindowFrame windowFrame: CGRect?) -> CGRect {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return .zero }
        let desktopTop = primary.frame.maxY

        var chosen: NSScreen?
        if let wf = windowFrame,
           let idx = Geometry.screenIndex(forWindow: wf, screens: screens.map(\.frame), desktopTop: desktopTop) {
            chosen = screens[idx]
        }
        let screen = chosen ?? NSScreen.main ?? primary
        return Geometry.axVisibleFrame(screen.visibleFrame, desktopTop: desktopTop)
    }
}
