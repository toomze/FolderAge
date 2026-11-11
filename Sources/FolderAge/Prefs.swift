import Foundation
import Combine

enum Theme: String, CaseIterable, Identifiable {
    case nature, digital, ocean
    var id: String { rawValue }

    var title: String {
        switch self {
        case .nature: return "Nature"
        case .digital: return "Digital"
        case .ocean: return "Ocean"
        }
    }

    var summary: String {
        switch self {
        case .nature: return "Чем дольше папку не трогают, тем сильнее бумага темнеет, мнётся и рвётся. Украшения — мухоморы, лягушка, подсолнух, пчела и другие."
        case .digital: return "Без изменений папка уходит от чёткой к ЭЛТ, глитчу и текстовому режиму. Украшения — робот, ракета, кассета, геймпад и другие."
        case .ocean: return "Без изменений стекло покрывается солью, ракушечником и ржавчиной. Украшения — осьминог, медуза, краб, морской конёк и другие."
        }
    }

    /// Картинка для карточки выбора темы — крайнее состояние: самая старая и заброшенная папка.
    var previewKey: String {
        switch self {
        case .nature: return "s4-mushrooms"
        case .digital: return "s4-robot"
        case .ocean: return "s4-octopus"
        }
    }

    /// Украшения темы. Номер украшения у папки: 0 — без украшения, 1…8 — по этому списку.
    var ornaments: [String] {
        switch self {
        case .nature: return ["mushrooms", "frog", "sunflower", "ladybug", "snail", "bee-honey", "cherries", "oak-acorn"]
        case .digital: return ["gamepad", "rocket", "cursor", "robot", "cassette", "lightning", "compact-disc", "floppy"]
        case .ocean: return ["octopus", "pearl-shell", "crab", "clownfish", "jellyfish", "starfish", "seahorse", "message-bottle"]
        }
    }

    func ornamentName(_ index: Int) -> String {
        index >= 1 && index <= ornaments.count ? ornaments[index - 1] : "none"
    }
    var isPixelArt: Bool { self == .digital }
}

enum TimeSpeed: String, CaseIterable, Identifiable {
    case slow, normal, fast, demo
    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: return "Медленно (сроки ×2)"
        case .normal: return "Обычно"
        case .fast: return "Быстро (сроки ×½)"
        case .demo: return "Демо: 1 день = 1 минута"
        }
    }

    /// Сколько реальных секунд длится один «день папки».
    var secondsPerDay: Double {
        switch self {
        case .slow: return 86_400 * 2
        case .normal: return 86_400
        case .fast: return 43_200
        case .demo: return 60
        }
    }
}

/// Настройки приложения, сохраняются в UserDefaults.
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private static let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { Prefs.d.set(enabled, forKey: "enabled") } }
    @Published var theme: Theme { didSet { Prefs.d.set(theme.rawValue, forKey: "theme") } }
    @Published var agingOn: Bool { didSet { Prefs.d.set(agingOn, forKey: "agingOn") } }
    @Published var overgrowthOn: Bool { didSet { Prefs.d.set(overgrowthOn, forKey: "overgrowthOn") } }
    @Published var speed: TimeSpeed { didSet { Prefs.d.set(speed.rawValue, forKey: "speed") } }
    @Published var keepFreshSystem: Bool { didSet { Prefs.d.set(keepFreshSystem, forKey: "keepFreshSystem") } }
    @Published var respectCustomIcons: Bool { didSet { Prefs.d.set(respectCustomIcons, forKey: "respectCustomIcons") } }
    @Published var wipeAlsoResetsAge: Bool { didSet { Prefs.d.set(wipeAlsoResetsAge, forKey: "wipeAlsoResetsAge") } }
    @Published var wipeAllInMenu: Bool { didSet { Prefs.d.set(wipeAllInMenu, forKey: "wipeAllInMenu") } }
    @Published var restoreOnQuit: Bool { didSet { Prefs.d.set(restoreOnQuit, forKey: "restoreOnQuit") } }
    @Published var autoCheckUpdates: Bool { didSet { Prefs.d.set(autoCheckUpdates, forKey: "autoCheckUpdates") } }
    @Published var scanMinutes: Int { didSet { Prefs.d.set(scanMinutes, forKey: "scanMinutes") } }
    @Published var watchDesktop: Bool { didSet { Prefs.d.set(watchDesktop, forKey: "watchDesktop") } }
    @Published var extraRoots: [String] { didSet { Prefs.d.set(extraRoots, forKey: "extraRoots") } }

    private init() {
        let d = Prefs.d
        d.register(defaults: [
            "enabled": true, "theme": Theme.nature.rawValue, "agingOn": true, "overgrowthOn": true, "speed": TimeSpeed.normal.rawValue,
            "keepFreshSystem": true, "respectCustomIcons": true, "wipeAlsoResetsAge": false,
            "wipeAllInMenu": false, "restoreOnQuit": false, "autoCheckUpdates": true,
            "scanMinutes": 15, "watchDesktop": true,
        ])
        enabled = d.bool(forKey: "enabled")
        theme = Theme(rawValue: d.string(forKey: "theme") ?? "") ?? .nature
        agingOn = d.bool(forKey: "agingOn")
        overgrowthOn = d.bool(forKey: "overgrowthOn")
        // Скорость и интервал проверки больше не настраиваются в окне — сбрасываем то,
        // что могло остаться от старых версий (например, демо-режим «1 день = 1 минута»).
        d.removeObject(forKey: "speed")
        d.removeObject(forKey: "scanMinutes")
        speed = .normal
        keepFreshSystem = d.bool(forKey: "keepFreshSystem")
        respectCustomIcons = d.bool(forKey: "respectCustomIcons")
        wipeAlsoResetsAge = d.bool(forKey: "wipeAlsoResetsAge")
        wipeAllInMenu = d.bool(forKey: "wipeAllInMenu")
        restoreOnQuit = d.bool(forKey: "restoreOnQuit")
        autoCheckUpdates = d.bool(forKey: "autoCheckUpdates")
        scanMinutes = d.integer(forKey: "scanMinutes")
        watchDesktop = d.bool(forKey: "watchDesktop")
        extraRoots = d.stringArray(forKey: "extraRoots") ?? []
    }

    /// Короткое описание порогов для текущей скорости.
    var thresholdSummary: String {
        func fmt(_ days: Double) -> String {
            if speed == .demo { return "\(Int(days)) мин" }
            let d = days * speed.secondsPerDay / 86_400
            if d < 14 { return "\(Int(d.rounded())) дн" }
            if d < 60 { return "\(Int((d / 7).rounded())) нед" }
            return "\(Int((d / 30).rounded())) мес"
        }
        let a = Stages.idleDays.map(fmt).joined(separator: " → ")
        return "Без изменений: \(a)\nУкрашения меняются раз в сутки"
    }
}
