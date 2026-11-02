// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CoreGraphics
import WossCore

/// Global Ctrl+Option hotkeys via a CGEventTap. A matched keystroke is swallowed
/// (callback returns nil) so it never reaches the focused app.
///
/// THREADING: macOS waits for the tap's answer before it delivers each keystroke, so the tap
/// runs on its own thread. If it shared the main thread, anything slow there (for example
/// waiting on a frozen app's window) would make the whole keyboard lag. Only `table` and
/// `modalActive` are shared between the two threads, and both sit behind a lock. All real
/// work (moving windows, swap mode) is handed to the main thread.
///
/// While `modalActive` is true (swap mode), EVERY keystroke is swallowed and handed to
/// `modalHandler` instead, so plain keys like "1" can be used without modifiers.
final class HotkeyListener {
    /// Both closures are only ever called on the main thread.
    var onAction: ((HotkeyAction, String) -> Void)?
    /// (keyCode, ctrl+option held)
    var modalHandler: ((Int, Bool) -> Void)?

    private let lock = NSLock()
    private var currentTable = HotkeyTable(layouts: [])
    private var isModal = false

    /// Thread-safe: written on the main thread, read on the tap thread.
    var table: HotkeyTable {
        get { lock.lock(); defer { lock.unlock() }; return currentTable }
        set { lock.lock(); currentTable = newValue; lock.unlock() }
    }

    /// Thread-safe: written on the main thread, read on the tap thread.
    var modalActive: Bool {
        get { lock.lock(); defer { lock.unlock() }; return isModal }
        set { lock.lock(); isModal = newValue; lock.unlock() }
    }

    private var tap: CFMachPort?     // set once, before the tap thread starts
    private var worker: Thread?

    var isRunning: Bool { worker != nil }

    /// Returns false if macOS refused to create the tap (usually: permission not granted yet).
    /// The tap is created here so success or failure is known immediately; the thread only
    /// serves its events.
    @discardableResult
    func start() -> Bool {
        guard worker == nil else { return true }

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

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return false }
        self.tap = tap

        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun() // serves the tap until the app quits
        }
        thread.name = "woss.hotkeys"
        thread.qualityOfService = .userInteractive
        thread.start()
        worker = thread
        return true
    }

    private func action(for hotkey: String) -> HotkeyAction? {
        lock.lock()
        defer { lock.unlock() }
        return currentTable.action(for: hotkey)
    }

    /// Runs on the tap thread.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables a tap that is too slow; turn it back on instead of silently dying.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // Exactly Ctrl+Option: ⌃⌥⌘Q or ⌃⌥⇧A must stay untouched for other apps.
        let relevant: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        let wanted: CGEventFlags = [.maskControl, .maskAlternate]
        let hasModifiers = event.flags.intersection(relevant) == wanted

        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        // Holding a key sends repeats; acting on them would race through a whole loop.
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        // Modal mode (swap): take every key.
        if modalActive {
            if !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.modalHandler?(keycode, hasModifiers)
                }
            }
            return nil
        }

        guard hasModifiers else { return Unmanaged.passUnretained(event) }
        guard let hotkey = KeyCodes.hotkey(forKeyCode: keycode),
              let action = action(for: hotkey)
        else { return Unmanaged.passUnretained(event) }

        if !isRepeat {
            DispatchQueue.main.async { [weak self] in
                self?.onAction?(action, hotkey)
            }
        }
        return nil // swallow (also the repeats)
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
