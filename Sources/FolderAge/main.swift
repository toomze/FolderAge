import AppKit

// Приложение живёт только в строке меню: без иконки в Dock (см. LSUIElement в Info.plist).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
