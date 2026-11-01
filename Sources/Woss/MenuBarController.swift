import AppKit
import ServiceManagement

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let infoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")

    var onPreferences: (() -> Void)?
    var onReload: (() -> Void)?

    override init() {
        super.init()

        if let button = statusItem.button {
            button.image = MenuBarController.menuIcon()
            if button.image == nil { button.title = "⚙️" }
        }

        let menu = NSMenu()
        menu.delegate = self

        infoItem.isEnabled = false
        menu.addItem(infoItem)
        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(preferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let reload = NSMenuItem(title: "Reload Layouts", action: #selector(reload), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        loginItem.action = #selector(toggleLaunchAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Woss",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func setLayoutCount(_ n: Int) {
        infoItem.title = "\(n) layouts loaded"
    }

    /// The old Gridshift menu bar icon when running from the built Woss.app,
    /// or a built-in system symbol when running via `swift run`.
    private static func menuIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 22, height: 22) // the PNG is 44px = 22pt @2x
            image.isTemplate = true                    // auto-tints for light/dark menu bar
            return image
        }
        let symbol = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Woss")
        symbol?.isTemplate = true
        return symbol
    }

    // MARK: - Launch at login

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("⚠️ Launch at Login failed: \(error.localizedDescription)")
            print("   (This only works from the built Woss.app, not from `swift run`.)")
        }
    }

    @objc private func preferences() { onPreferences?() }
    @objc private func reload() { onReload?() }
}
