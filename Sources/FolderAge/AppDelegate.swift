import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "leaf", accessibilityDescription: AppConfig.appName)
            img?.isTemplate = true
            button.image = img
            button.toolTip = AppConfig.appName
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        DecayEngine.shared.start()
        if Prefs.shared.autoCheckUpdates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { Updater.check(interactive: false) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Prefs.shared.restoreOnQuit { DecayEngine.shared.restoreAll() }
    }

    // Меню собирается каждый раз при открытии — так пункт «Протереть все» появляется сразу после включения в настройках.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if Prefs.shared.wipeAllInMenu {
            menu.addItem(item("Протереть все папки", #selector(wipeAll), ""))
            menu.addItem(.separator())
        }
        menu.addItem(item("Настройки…", #selector(openSettings), ","))
        menu.addItem(item("Обновить программу…", #selector(checkUpdates), ""))
        menu.addItem(.separator())
        menu.addItem(item("Выход", #selector(quit), "q"))
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.title = "\(AppConfig.appName) — Настройки"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func checkUpdates() { Updater.check(interactive: true) }
    @objc private func wipeAll() { DecayEngine.shared.wipeAll() }
    @objc private func quit() { NSApp.terminate(nil) }
}
