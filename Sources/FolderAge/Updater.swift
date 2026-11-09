import AppKit
import Combine
import ServiceManagement
import Sparkle

/// Автообновление через Sparkle: лента — appcast.xml в последнем релизе на GitHub (SUFeedURL в Info.plist).
final class Updater {
    static let shared = Updater()

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private var controller: SPUStandardUpdaterController?
    private var cancellables = Set<AnyCancellable>()

    func start() {
        let c = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller = c
        c.updater.automaticallyChecksForUpdates = Prefs.shared.autoCheckUpdates
        Prefs.shared.$autoCheckUpdates
            .dropFirst()
            .sink { [weak c] value in c?.updater.automaticallyChecksForUpdates = value }
            .store(in: &cancellables)
    }

    /// Пункт меню «Обновить программу…»: проверка, загрузка, установка и перезапуск — всё внутри Sparkle.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }
}

/// Автозапуск при входе (macOS 13+).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("FolderAge login item: \(error.localizedDescription)")
        }
    }
}
