import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// All the screen math, kept free of AppKit so it can be unit-tested.
///
/// Two coordinate systems are involved:
///  - "Cocoa": what NSScreen reports. Origin bottom-left, y grows UP.
///  - "AX":    what the Accessibility API uses for windows. Origin top-left of the
///             primary screen, y grows DOWN.
public enum Geometry {
    /// Cocoa visible frame (excludes menu bar/Dock) -> AX-space rect.
    /// `desktopTop` is the primary screen's frame.maxY in Cocoa space.
    public static func axVisibleFrame(_ visible: CGRect, desktopTop: CGFloat) -> CGRect {
        let topEdge: CGFloat = visible.origin.y + visible.size.height
        let axY: CGFloat = desktopTop - topEdge
        return CGRect(x: visible.origin.x, y: axY, width: visible.size.width, height: visible.size.height)
    }

    /// Length of the overlap between [aStart, aEnd] and [bStart, bEnd] (0 if disjoint).
    private static func overlap(_ aStart: CGFloat, _ aEnd: CGFloat, _ bStart: CGFloat, _ bEnd: CGFloat) -> CGFloat {
        let lo: CGFloat = max(aStart, bStart)
        let hi: CGFloat = min(aEnd, bEnd)
        return max(0, hi - lo)
    }

    /// Which screen does a window (AX-space frame) overlap the most? Screens are Cocoa frames.
    /// Returns nil if it overlaps none.
    public static func screenIndex(forWindow win: CGRect, screens: [CGRect], desktopTop: CGFloat) -> Int? {
        let winLeft: CGFloat = win.origin.x
        let winRight: CGFloat = win.origin.x + win.size.width
        // convert the window's vertical span from AX (top-down) to Cocoa (bottom-up)
        let winBottom: CGFloat = desktopTop - win.origin.y - win.size.height
        let winTop: CGFloat = winBottom + win.size.height

        var best: Int?
        var bestOverlap: CGFloat = 0
        for (i, sf) in screens.enumerated() {
            let ox = overlap(winLeft, winRight, sf.origin.x, sf.origin.x + sf.size.width)
            let oy = overlap(winBottom, winTop, sf.origin.y, sf.origin.y + sf.size.height)
            let area: CGFloat = ox * oy
            if area > bestOverlap {
                bestOverlap = area
                best = i
            }
        }
        return best
    }

    /// Target window frame (AX-space) for a layout rectangle on a screen (AX-space visible frame).
    /// Layout y is measured from the bottom, so it is flipped here.
    public static func snapFrame(_ r: RelRect, in screen: CGRect) -> CGRect {
        let sx: CGFloat = screen.origin.x
        let sy: CGFloat = screen.origin.y
        let sw: CGFloat = screen.size.width
        let sh: CGFloat = screen.size.height

        let rx = CGFloat(r.x)
        let ry = CGFloat(r.y)
        let rw = CGFloat(r.w)
        let rh = CGFloat(r.h)

        let x: CGFloat = sx + rx * sw
        let flipped: CGFloat = 1 - ry - rh
        let y: CGFloat = sy + flipped * sh
        return CGRect(x: x, y: y, width: rw * sw, height: rh * sh)
    }

    /// Scale a window's size, keeping it pinned to whichever screen edge it is closer to
    /// on each axis, and never letting it leave the screen. All rects in AX-space.
    public static func resizeRelative(window: CGRect, screen: CGRect, scaleW: Double, scaleH: Double) -> CGRect {
        let wx: CGFloat = window.origin.x
        let wy: CGFloat = window.origin.y
        let ww: CGFloat = window.size.width
        let wh: CGFloat = window.size.height
        let sx: CGFloat = screen.origin.x
        let sy: CGFloat = screen.origin.y
        let sw: CGFloat = screen.size.width
        let sh: CGFloat = screen.size.height

        let newW: CGFloat = min(ww * CGFloat(scaleW), sw)
        let newH: CGFloat = min(wh * CGFloat(scaleH), sh)

        // horizontal: pin to the closer edge, then clamp on-screen
        let distLeft: CGFloat = wx - sx
        let distRight: CGFloat = (sx + sw) - (wx + ww)
        var newX: CGFloat = distLeft <= distRight ? wx : (wx + ww - newW)
        let maxX: CGFloat = sx + sw - newW
        newX = max(sx, min(newX, maxX))

        // vertical: same idea (AX y grows downward, so "top" is the smaller y)
        let distTop: CGFloat = wy - sy
        let distBottom: CGFloat = (sy + sh) - (wy + wh)
        var newY: CGFloat = distTop <= distBottom ? wy : (wy + wh - newH)
        let maxY: CGFloat = sy + sh - newH
        newY = max(sy, min(newY, maxY))

        return CGRect(x: newX, y: newY, width: newW, height: newH)
    }
}
