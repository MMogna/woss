import AppKit
import ApplicationServices
import CoreGraphics

/// A window we can both see (frame) and move (AX element).
struct SwapCandidate {
    let element: AXUIElement
    let frame: CGRect
}

extension WindowManager {
    /// Visible, normal windows of all other apps on the current Space.
    ///
    /// The window LIST comes from CGWindowListCopyWindowInfo (gives z-order, visibility and
    /// frames without needing Screen Recording permission). Each entry is then matched to its
    /// Accessibility element by frame, because only AX lets us move/resize it.
    func swappableWindows() -> [SwapCandidate] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let myPid = ProcessInfo.processInfo.processIdentifier
        var axWindowsByPid: [pid_t: [(element: AXUIElement, frame: CGRect)]] = [:]
        var usedByPid: [pid_t: Set<Int>] = [:]
        var found: [SwapCandidate] = []

        for info in infoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pidValue = info[kCGWindowOwnerPID as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            let pid = pid_t(pidValue)
            if pid == myPid { continue }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha < 0.05 { continue }
            if bounds.width < 100 || bounds.height < 60 { continue }

            if axWindowsByPid[pid] == nil {
                axWindowsByPid[pid] = standardAXWindows(pid: pid)
            }
            let candidates = axWindowsByPid[pid] ?? []
            var used = usedByPid[pid] ?? []

            let match = candidates.indices.first { i in
                !used.contains(i) && framesMatch(candidates[i].frame, bounds)
            }
            if let i = match {
                used.insert(i)
                usedByPid[pid] = used
                found.append(SwapCandidate(element: candidates[i].element, frame: bounds))
            }
        }
        return found
    }

    /// Exchange the two windows' frames (position AND size).
    func swapWindows(_ a: SwapCandidate, _ b: SwapCandidate) {
        applyFrame(b.frame, to: a.element)
        applyFrame(a.frame, to: b.element)
    }

    // MARK: - helpers

    private func standardAXWindows(pid: pid_t) -> [(element: AXUIElement, frame: CGRect)] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3) // don't hang on a frozen app

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let array = value as? [AnyObject]
        else { return [] }

        var result: [(element: AXUIElement, frame: CGRect)] = []
        for object in array {
            let element = object as! AXUIElement

            var subroleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef) == .success,
               let subrole = subroleRef as? String,
               subrole != (kAXStandardWindowSubrole as String) {
                continue // skip dialogs, palettes, popovers...
            }
            guard let f = frame(of: element) else { continue }
            result.append((element: element, frame: f))
        }
        return result
    }

    private func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        let tolerance: CGFloat = 4
        return abs(a.origin.x - b.origin.x) <= tolerance
            && abs(a.origin.y - b.origin.y) <= tolerance
            && abs(a.size.width - b.size.width) <= tolerance
            && abs(a.size.height - b.size.height) <= tolerance
    }

    /// size → position → size: moving to a different-sized screen needs the first size, and
    /// the last one corrects any clamping done by the system after the move.
    func applyFrame(_ rect: CGRect, to window: AXUIElement) {
        var size = rect.size
        var point = rect.origin
        if let sv = AXValueCreate(.cgSize, &size) {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv)
        }
        if let pv = AXValueCreate(.cgPoint, &point) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        }
        if let sv = AXValueCreate(.cgSize, &size) {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv)
        }
    }
}
