import AppKit
import ApplicationServices
import WossCore

/// Talks to other apps' windows through the Accessibility API.
/// Everything here must run on the main thread.
final class WindowManager {
    private var cycle = CycleState()

    // MARK: - public actions

    /// Hotkey press: cycles through `rects` if the same key is pressed again on the same window.
    func snapStep(rects: [RelRect], hotkey: String) {
        guard !rects.isEmpty, let win = focusedWindow() else { return }
        let step = cycle.advance(window: win.id, hotkey: hotkey, count: rects.count)
        let screen = screenFrameAX(forWindowFrame: frame(of: win.element))
        let target = Geometry.snapFrame(rects[step], in: screen)
        setFrame(target, of: win.element)
    }

    func resize(_ action: ResizeAction) {
        guard let win = focusedWindow(), let current = frame(of: win.element) else { return }
        let screen = screenFrameAX(forWindowFrame: current)
        let target = Geometry.resizeRelative(window: current, screen: screen,
                                             scaleW: action.scaleW, scaleH: action.scaleH)
        setFrame(target, of: win.element)
        cycle.reset() // geometry changed under the cycle, start fresh next time
    }

    // MARK: - Accessibility helpers

    private struct FocusedWindow {
        let element: AXUIElement
        let id: WindowID
    }

    private func focusedWindow() -> FocusedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value
        else { return nil }
        let element = value as! AXUIElement

        var title = ""
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let s = titleRef as? String {
            title = s
        }
        return FocusedWindow(element: element, id: WindowID(pid: pid, title: title))
    }

    func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func setFrame(_ rect: CGRect, of window: AXUIElement) {
        var point = rect.origin
        var size = rect.size
        if let pv = AXValueCreate(.cgPoint, &point) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        }
        if let sv = AXValueCreate(.cgSize, &size) {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv)
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
