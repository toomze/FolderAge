import AppKit
import ServiceManagement

/// Проверка обновлений через GitHub Releases (AppConfig.githubRepo).
enum Updater {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func check(interactive: Bool) {
        guard !AppConfig.githubRepo.isEmpty,
              let url = URL(string: "https://api.github.com/repos/\(AppConfig.githubRepo)/releases/latest") else {
            if interactive {
                alert("Проверка обновлений пока не настроена",
                      "Укажите репозиторий с релизами в AppConfig.githubRepo и пересоберите приложение.")
            }
            return
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    if interactive { alert("Не удалось проверить обновления", error?.localizedDescription ?? "Попробуйте позже.") }
                    return
                }
                let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if latest.compare(currentVersion, options: .numeric) == .orderedDescending {
                    let a = NSAlert()
                    a.messageText = "Доступна версия \(latest)"
                    a.informativeText = "У вас установлена \(currentVersion). Открыть страницу загрузки?"
                    a.addButton(withTitle: "Скачать")
                    a.addButton(withTitle: "Позже")
                    NSApp.activate(ignoringOtherApps: true)
                    if a.runModal() == .alertFirstButtonReturn,
                       let s = json["html_url"] as? String, let page = URL(string: s) {
                        NSWorkspace.shared.open(page)
                    }
                } else if interactive {
                    alert("У вас последняя версия", "\(AppConfig.appName) \(currentVersion)")
                }
            }
        }.resume()
    }

    static func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
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
