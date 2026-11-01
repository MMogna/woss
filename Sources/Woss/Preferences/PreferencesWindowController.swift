import AppKit
import SwiftUI

final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(state: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let model = PrefsModel(layouts: state.layouts, keys: state.keys)
        let view = PrefsView(
            model: model,
            onSave: { [weak self] in
                state.apply(layouts: model.flattenedLayouts(), keys: model.keys)
                self?.window?.close()
            },
            onCancel: { [weak self] in
                self?.window?.close()
            }
        )

        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = "Woss — Shortcuts"
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        w.setContentSize(NSSize(width: 860, height: 720))
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        window = w

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
