// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import WossCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let windowManager = WindowManager()
    private let listener = HotkeyListener()
    private lazy var swap = SwapController(windowManager: windowManager)
    private let menuBar = MenuBarController()
    private let prefs = PreferencesWindowController()
    private var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar only, no Dock icon

        state.onChange = { [weak self] in
            guard let self else { return }
            self.listener.table = self.state.table
            self.menuBar.setLayoutCount(self.state.layouts.count)
        }
        state.reloadFromDisk()

        listener.onAction = { [weak self] action, hotkey in
            switch action {
            case .snap(let rects): self?.windowManager.snapStep(rects: rects, hotkey: hotkey)
            case .resize(let a): self?.windowManager.resize(a)
            case .swapMode: self?.swap.toggle()
            case .tileAll: self?.windowManager.tileAll()
            }
        }

        swap.onActiveChanged = { [weak self] active in
            self?.listener.modalActive = active
        }
        listener.modalHandler = { [weak self] keyCode, hasModifiers in
            guard let self else { return }
            self.swap.handleKey(keyCode: keyCode,
                                hasHotkeyModifiers: hasModifiers,
                                swapKey: self.state.keys.swap)
        }

        // Swap mode must not outlive the desktop it was started on.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.swap.end() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.swap.end() }

        menuBar.onReload = { [weak self] in self?.state.reloadFromDisk() }
        menuBar.onPreferences = { [weak self] in
            guard let self else { return }
            self.prefs.show(state: self.state)
        }

        startListenerWhenAllowed()
        print("⚙️  Woss running — look for the grid icon in your menu bar.")
        print("   Ctrl+Option + hotkey to snap  |  Preferences… to rebind keys")
    }

    /// Without Accessibility permission the event tap can't be created. Ask for it, then keep
    /// retrying every 2s so hotkeys start working the moment the permission is granted.
    private func startListenerWhenAllowed() {
        if listener.start() { return }

        if !Accessibility.isTrusted {
            print("⚠️  Accessibility permission required.")
            print("   System Settings → Privacy & Security → Accessibility → enable this app (or Terminal).")
            Accessibility.promptIfNeeded()
        } else {
            print("⚠️  Could not create the key listener. If it persists, also enable")
            print("   System Settings → Privacy & Security → Input Monitoring for this app (or Terminal).")
        }

        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.listener.start() {
                print("✓ Hotkeys active.")
                timer.invalidate()
                self.retryTimer = nil
            }
        }
    }
}
