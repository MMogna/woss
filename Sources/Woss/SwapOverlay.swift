import AppKit

/// Draws a numbered badge on top of every window while swap mode is active.
/// Each badge is its own tiny borderless panel that never takes focus or mouse events.
final class SwapOverlay {
    private static let size: CGFloat = 44
    private var panels: [NSPanel] = []
    private var badges: [BadgeView] = []

    /// `centers` are in Accessibility coordinates (origin top-left of the primary screen).
    func show(labels: [String], centers: [CGPoint]) {
        hide()
        let desktopTop = NSScreen.screens.first?.frame.maxY ?? 0
        let s = SwapOverlay.size

        for (i, label) in labels.enumerated() where i < centers.count {
            let c = centers[i]
            let rect = NSRect(x: c.x - s / 2, y: desktopTop - c.y - s / 2, width: s, height: s)

            let panel = NSPanel(contentRect: rect,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered,
                                defer: false)
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

            let badge = BadgeView(frame: NSRect(origin: .zero, size: rect.size))
            badge.label = label
            panel.contentView = badge
            panel.orderFrontRegardless()

            panels.append(panel)
            badges.append(badge)
        }
    }

    /// Highlights the first pick (pass nil to clear).
    func select(_ index: Int?) {
        for (i, badge) in badges.enumerated() {
            badge.isSelected = (i == index)
            badge.needsDisplay = true
        }
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        badges.removeAll()
    }
}

final class BadgeView: NSView {
    var label = ""
    var isSelected = false

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)

        let fill: NSColor = isSelected ? NSColor.controlAccentColor : NSColor.black.withAlphaComponent(0.85)
        fill.setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        let text = label.uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2),
                  withAttributes: attrs)
    }
}
