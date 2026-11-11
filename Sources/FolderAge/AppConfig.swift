import Foundation

/// Всё, что нужно поменять под себя перед сборкой, — здесь.
enum AppConfig {
    static let appName = "FolderAge"

    /// Ссылка на фидбек внизу окна настроек.
    static let telegramURL = URL(string: "https://t.me/toomze")!
    static let telegramLabel = "@toomze"

    /// Адрес счётчика хлопков (Cloudflare Worker из server/claps-worker.js).
    /// Если nil — кнопка «Похлопать» не показывается.
    static let clapsURL: URL? = URL(string: "https://folderage-claps.alextoomze.workers.dev/claps")

    /// Репозиторий GitHub в формате "owner/repo", где публикуются релизы с .dmg.
    /// Пока пусто — пункт «Обновить программу» сообщает, что проверка не настроена.
    static let githubRepo = "toomze/FolderAge"
}

/// Пороги стадий в «днях папки». Скорость времени в настройках растягивает или сжимает день.
enum Stages {
    /// Сколько дней в папке ничего не меняли: A1 < 14 ≤ A2 < 30 ≤ A3 < 90 ≤ A4.
    /// Изменение — любой файл внутри создан, изменён, удалён или переименован, а также переименование самой папки.
    static let idleDays: [Double] = [14, 30, 90]

    static func stage(_ days: Double, _ bounds: [Double]) -> Int {
        bounds.firstIndex(where: { days < $0 }) ?? bounds.count
    }
}
