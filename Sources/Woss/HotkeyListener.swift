import AppKit
import CoreGraphics
import WossCore

/// Global Ctrl+Option hotkeys via a CGEventTap. A matched keystroke is swallowed
/// (callback returns nil) so it never reaches the focused app.
///
/// While `modalActive` is true (swap mode), EVERY keystroke is swallowed and handed to
/// `modalHandler` instead, so plain keys like "1" can be used without modifiers.
final class HotkeyListener {
    var table = HotkeyTable(layouts: [])
    var onAction: ((HotkeyAction, String) -> Void)?

    var modalActive = false
    /// (keyCode, ctrl+option held)
    var modalHandler: ((Int, Bool) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    /// Returns false if macOS refused to create the tap (usually: permission not granted yet).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let me = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap, // NOT listen-only: we need to be able to swallow events
            eventsOfInterest: mask,
            callback: hotkeyTapCallback,
            userInfo: me
        ) else { return false }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables a tap that is too slow; turn it back on instead of silently dying.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let required: CGEventFlags = [.maskControl, .maskAlternate]
        let hasModifiers = event.flags.contains(required)
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Modal mode (swap): take every key.
        if modalActive {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.modalHandler?(keycode, hasModifiers)
                }
            }
            return nil
        }

        guard hasModifiers else { return Unmanaged.passUnretained(event) }
        guard let hotkey = KeyCodes.hotkey(forKeyCode: keycode),
              let action = table.action(for: hotkey)
        else { return Unmanaged.passUnretained(event) }

        // Do the real work outside the tap callback so the callback returns immediately.
        DispatchQueue.main.async { [weak self] in
            self?.onAction?(action, hotkey)
        }
        return nil // swallow
    }
}

/// C-style callback: can't capture anything, so `self` comes through `userInfo`.
private func hotkeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let listener = Unmanaged<HotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()
    return listener.handle(type: type, event: event)
}
