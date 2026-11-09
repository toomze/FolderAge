import Foundation

/// Всё, что нужно поменять под себя перед сборкой, — здесь.
enum AppConfig {
    static let appName = "FolderAge"

    /// Ссылка на фидбек внизу окна настроек.
    static let telegramURL = URL(string: "https://t.me/toomze")!
    static let telegramLabel = "@toomze"

    /// Репозиторий GitHub в формате "owner/repo", где публикуются релизы с .dmg.
    /// Пока пусто — пункт «Обновить программу» сообщает, что проверка не настроена.
    static let githubRepo = "toomze/FolderAge"
}

/// Пороги стадий в «днях папки». Скорость времени в настройках растягивает или сжимает день.
enum Stages {
    /// Возраст (дата создания): A1 < 14 ≤ A2 < 30 ≤ A3 < 90 ≤ A4 — четыре стадии
    static let ageDays: [Double] = [14, 30, 90]
    /// Без изменений: N1 < 3 ≤ N2 < 7 ≤ N3 < 14 ≤ N4 < 28 ≤ N5
    static let neglectDays: [Double] = [3, 7, 14, 28]

    static func stage(_ days: Double, _ bounds: [Double]) -> Int {
        bounds.firstIndex(where: { days < $0 }) ?? bounds.count
    }
}
