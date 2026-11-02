// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI
import WossCore

/// Click it, press a key, and it records that key (the ⌃⌥ modifier is fixed, so only the
/// trailing key is captured). Right-click to unbind.
struct KeyCaptureField: NSViewRepresentable {
    @Binding var hotkey: String

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.hotkey = hotkey
        let binding = $hotkey
        view.onChange = { binding.wrappedValue = $0 }
        return view
    }

    func updateNSView(_ view: KeyCaptureView, context: Context) {
        let binding = $hotkey
        view.onChange = { binding.wrappedValue = $0 }
        if view.hotkey != hotkey {
            view.hotkey = hotkey
            view.needsDisplay = true
        }
    }
}

final class KeyCaptureView: NSView {
    var hotkey = ""
    var onChange: ((String) -> Void)?

    private var capturing = false
    private var message: String?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        capturing = true
        message = "Press a key…"
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard capturing else { return }
        guard let hk = KeyCodes.hotkey(forKeyCode: Int(event.keyCode)) else {
            message = "Unsupported key" // a key the listener could never match
            needsDisplay = true
            return
        }
        hotkey = hk
        message = nil
        capturing = false
        onChange?(hk)
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        hotkey = ""
        message = nil
        capturing = false
        onChange?("")
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        capturing = false
        message = nil
        needsDisplay = true
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)

        let accent = NSColor.controlAccentColor
        if capturing {
            accent.withAlphaComponent(0.15).setFill()
        } else {
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
        }
        path.fill()

        if capturing {
            accent.setStroke()
            path.lineWidth = 1.5
        } else {
            NSColor.labelColor.withAlphaComponent(0.18).setStroke()
            path.lineWidth = 1
        }
        path.stroke()

        let text = message ?? Hotkey.display(hotkey, character: KeyLabels.character(forHotkey: hotkey))
        let color: NSColor
        if capturing {
            color = accent
        } else if hotkey.isEmpty {
            color = NSColor.secondaryLabelColor
        } else {
            color = NSColor.labelColor
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2),
                  withAttributes: attrs)
    }
}
