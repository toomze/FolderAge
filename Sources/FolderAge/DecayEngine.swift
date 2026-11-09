import AppKit
import Combine

/// Что приложение помнит о каждой папке между запусками.
struct FolderRecord: Codable {
    var activity: Date              // последнее замеченное изменение содержимого
    var signature: String?          // отпечаток списка файлов (ловит удаления)
    var applied: String?            // какая иконка сейчас поставлена нами
    var wipedAt: Date?              // когда протирали
    var ageResetAt: Date?           // когда омолаживали
    var excluded: Bool = false      // «не трогать эту папку»
}

/// Строка для списка в настройках.
struct FolderInfo: Identifiable {
    let id: String
    let name: String
    let created: Date
    let lastChange: Date
    let age: Int
    let neglect: Int
    let iconKey: String?
    let excluded: Bool
    let foreignIcon: Bool

    var stageLabel: String {
        if excluded { return "не трогаем" }
        if foreignIcon { return "своя иконка" }
        return "A\(age + 1) · N\(neglect + 1)"
    }

    var subtitle: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        var s = "создана \(f.localizedString(for: created, relativeTo: Date())) · изменялась \(f.localizedString(for: lastChange, relativeTo: Date()))"
        if excluded { s += " · не трогаем" } else if foreignIcon { s += " · своя иконка" }
        return s
    }
}

/// Сырые данные о папке, собранные в фоне.
private struct Observation {
    let path: String
    let name: String
    let created: Date
    let maxDate: Date
    let signature: String
    let hasIconFile: Bool
}

final class DecayEngine: ObservableObject {
    static let shared = DecayEngine()

    @Published private(set) var folders: [FolderInfo] = []
    @Published private(set) var lastScan: Date?

    private let prefs = Prefs.shared
    private var records: [String: FolderRecord] = [:]
    private let queue = DispatchQueue(label: "folderage.scan", qos: .utility)
    private var timer: Timer?
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private var scanning = false
    private var cancellables = Set<AnyCancellable>()
    private var imageCache: [String: NSImage] = [:]

    // MARK: lifecycle

    func start() {
        load()
        prefs.objectWillChange
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reconfigure() }
            .store(in: &cancellables)
        // Смена темы: перерисовать все папки сразу, не дожидаясь общего пересканирования.
        prefs.$theme
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.imageCache.removeAll()
                self?.scheduleScan(after: 0.1)
            }
            .store(in: &cancellables)
        reconfigure()
    }

    private func reconfigure() {
        timer?.invalidate()
        let interval: TimeInterval = prefs.speed == .demo ? 20 : TimeInterval(max(prefs.scanMinutes, 1) * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.scheduleScan(after: 0) }
        rewatch()
        scheduleScan(after: 0)
    }

    var roots: [URL] {
        var r: [URL] = []
        if prefs.watchDesktop, let desk = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            r.append(desk)
        }
        r += prefs.extraRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
        return r
    }

    /// Следим за самими корневыми папками: новая папка на столе получает иконку почти сразу.
    private func rewatch() {
        watchers.forEach { $0.cancel() }
        watchers = []
        for root in roots {
            let fd = open(root.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
            src.setEventHandler { [weak self] in self?.scheduleScan(after: 2) }
            src.setCancelHandler { close(fd) }
            src.resume()
            watchers.append(src)
        }
    }

    func scheduleScan(after seconds: Double) {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.scan() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    // MARK: scanning

    private func scan() {
        guard !scanning else { scheduleScan(after: 2); return }
        scanning = true
        let rootList = roots
        queue.async { [weak self] in
            let obs = rootList.flatMap { DecayEngine.observe(root: $0) }
            DispatchQueue.main.async {
                self?.merge(obs, roots: rootList)
                self?.scanning = false
            }
        }
    }

    private static func observe(root: URL) -> [Observation] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .creationDateKey]
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        let now = Date()
        var out: [Observation] = []
        for url in items {
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.isDirectory == true, v.isPackage != true, v.isSymbolicLink != true else { continue }
            let created = min(v.creationDate ?? now, now)
            var maxDate = created
            let names = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
                .filter { $0 != "Icon\r" && $0 != ".DS_Store" }
                .sorted()
            let dateKeys: [URLResourceKey] = [.contentModificationDateKey, .addedToDirectoryDateKey]
            if let en = fm.enumerator(at: url, includingPropertiesForKeys: dateKeys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                var count = 0
                for case let f as URL in en {
                    if en.level > 3 { en.skipDescendants(); continue }
                    if f.lastPathComponent == "Icon\r" { continue }
                    count += 1
                    if count > 3000 { break }
                    if let fv = try? f.resourceValues(forKeys: Set(dateKeys)) {
                        if let m = fv.contentModificationDate, m > maxDate { maxDate = m }
                        if let a = fv.addedToDirectoryDate, a > maxDate { maxDate = a }
                    }
                }
            }
            out.append(Observation(
                path: url.path,
                name: url.lastPathComponent,
                created: created,
                maxDate: min(maxDate, now),
                signature: "\(names.count):\(fnv(names.joined(separator: "/")))",
                hasIconFile: fm.fileExists(atPath: url.appendingPathComponent("Icon\r").path)
            ))
        }
        return out
    }

    private func merge(_ obs: [Observation], roots: [URL]) {
        let now = Date()
        let spd = prefs.speed.secondsPerDay
        var seen = Set<String>()
        var infos: [FolderInfo] = []
        var replacements: [(path: String, key: String)] = []

        for o in obs {
            seen.insert(o.path)
            var r = records[o.path] ?? FolderRecord(activity: o.maxDate)
            if let sig = r.signature, sig != o.signature { r.activity = now }   // что-то добавили или удалили
            r.signature = o.signature
            if o.maxDate > r.activity { r.activity = o.maxDate }

            let ageBase = max(o.created, r.ageResetAt ?? .distantPast)
            let neglectBase = max(r.activity, r.wipedAt ?? .distantPast, ageBase)
            let a = prefs.agingOn ? Stages.stage(now.timeIntervalSince(ageBase) / spd, Stages.ageDays) : 0
            let n = prefs.overgrowthOn ? Stages.stage(now.timeIntervalSince(neglectBase) / spd, Stages.neglectDays) : 0
            let foreign = o.hasIconFile && r.applied == nil
            let key = DecayEngine.iconKey(age: a, neglect: n, path: o.path)
            let themedKey = "\(prefs.theme.rawValue)/\(key)"

            if prefs.enabled && !r.excluded && !(foreign && prefs.respectCustomIcons) {
                if key == "a0n0" && prefs.keepFreshSystem {
                    if r.applied != nil, setIcon(nil, o.path) { r.applied = nil }
                } else if r.applied != themedKey, image(themedKey) != nil {
                    if r.applied == nil {
                        if let img = image(themedKey), setIcon(img, o.path) { r.applied = themedKey }
                    } else {
                        replacements.append((o.path, themedKey))   // замена своей иконки — в два шага, ниже
                        r.applied = themedKey
                    }
                }
            } else if r.applied != nil, setIcon(nil, o.path) {
                r.applied = nil
            }
            records[o.path] = r
            infos.append(FolderInfo(id: o.path, name: o.name, created: o.created, lastChange: neglectBase,
                                    age: a, neglect: n, iconKey: r.applied, excluded: r.excluded,
                                    foreignIcon: foreign && prefs.respectCustomIcons))
        }

        let rootPaths = roots.map { $0.path + "/" }
        for k in Array(records.keys) where !seen.contains(k) && rootPaths.contains(where: { k.hasPrefix($0) }) {
            records.removeValue(forKey: k)   // папку удалили или переместили
        }
        folders = infos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        lastScan = now
        save()
        replaceIcons(replacements)
    }

    // MARK: actions

    func wipe(_ path: String) {
        records[path]?.wipedAt = Date()
        if prefs.wipeAlsoResetsAge { records[path]?.ageResetAt = Date() }
        save(); scheduleScan(after: 0)
    }

    func wipeAll() {
        let now = Date()
        for k in Array(records.keys) {
            records[k]?.wipedAt = now
            if prefs.wipeAlsoResetsAge { records[k]?.ageResetAt = now }
        }
        save(); scheduleScan(after: 0)
    }

    /// «Обновить»: папка снова свежая и чистая — без пыли и травы, исходного синего цвета.
    func refresh(_ path: String) {
        let now = Date()
        records[path]?.wipedAt = now
        records[path]?.ageResetAt = now
        save(); scheduleScan(after: 0)
    }

    func refreshAll() {
        let now = Date()
        for k in Array(records.keys) {
            records[k]?.wipedAt = now
            records[k]?.ageResetAt = now
        }
        save(); scheduleScan(after: 0)
    }

    func rejuvenate(_ path: String) {
        records[path]?.ageResetAt = Date()
        records[path]?.wipedAt = Date()
        save(); scheduleScan(after: 0)
    }

    func setExcluded(_ path: String, _ value: Bool) {
        records[path]?.excluded = value
        save(); scheduleScan(after: 0)
    }

    /// Вернуть системные иконки всем папкам, которые мы меняли.
    func restoreAll() {
        for (k, r) in records where r.applied != nil {
            if setIcon(nil, k) { records[k]?.applied = nil }
        }
        save()
        scheduleScan(after: 0.5)
    }

    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Добавить"
        panel.message = "Выберите папку, вложенные папки которой будут стареть и зарастать"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url, !prefs.extraRoots.contains(url.path) {
            prefs.extraRoots.append(url.path)
        }
    }

    func removeRoot(_ path: String) {
        for (k, r) in records where k.hasPrefix(path + "/") {
            if r.applied != nil { _ = setIcon(nil, k) }
            records.removeValue(forKey: k)
        }
        prefs.extraRoots.removeAll { $0 == path }
        save()
    }

    func thumbnail(_ info: FolderInfo) -> NSImage {
        if let k = info.iconKey, let img = image(k) { return img }
        return NSWorkspace.shared.icon(forFile: info.id)
    }

    // MARK: helpers

    static func iconKey(age: Int, neglect: Int, path: String) -> String {
        if neglect == 0 { return "a\(age)n0" }
        let variant = ["A", "B", "C"][Int(fnv32(path) % 3)]   // вариант закреплён за папкой
        return "a\(age)n\(neglect)\(variant)"
    }

    /// themedKey: "nature/a2n3B" — картинка из Icons/<тема>/<ключ>.png.
    func image(_ themedKey: String) -> NSImage? {
        if let img = imageCache[themedKey] { return img }
        let parts = themedKey.split(separator: "/", maxSplits: 1).map(String.init)
        let (theme, key) = parts.count == 2 ? (parts[0], parts[1]) : (Theme.nature.rawValue, themedKey)
        guard let url = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Icons/\(theme)"),
              let img = NSImage(contentsOf: url) else { return nil }
        imageCache[themedKey] = img
        return img
    }

    /// Замена уже стоящих своих иконок (смена темы или стадии).
    /// Finder кэширует иконки папок и при мгновенной замене часто показывает старую.
    /// Поэтому: 1) снимаем иконки со всех папок разом, 2) ждём, пока Finder это отрисует,
    /// 3) ставим новые и просим Finder перечитать каждую папку.
    private func replaceIcons(_ items: [(path: String, key: String)]) {
        guard !items.isEmpty else { return }
        let ws = NSWorkspace.shared
        for it in items { _ = ws.setIcon(nil, forFile: it.path, options: []); refreshInFinder(it.path) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            var changed = false
            for it in items {
                guard self.records[it.path]?.applied == it.key else { continue }   // пока ждали, всё поменялось ещё раз
                if let img = self.image(it.key), ws.setIcon(img, forFile: it.path, options: []) {
                    self.refreshInFinder(it.path)
                } else {
                    self.records[it.path]?.applied = nil
                    changed = true
                }
            }
            if let parent = items.first.map({ ($0.path as NSString).deletingLastPathComponent }) {
                ws.noteFileSystemChanged(parent)
            }
            if changed { self.save() }
        }
    }

    /// Просим Finder перечитать папку: обновляем дату изменения самой папки
    /// (содержимое и наша логика «активности» от этого не зависят) и шлём уведомление.
    private func refreshInFinder(_ path: String) {
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: path)
        NSWorkspace.shared.noteFileSystemChanged(path)
    }

    @discardableResult
    private func setIcon(_ image: NSImage?, _ path: String) -> Bool {
        let ok = NSWorkspace.shared.setIcon(image, forFile: path, options: [])
        if ok { refreshInFinder(path) }
        return ok
    }

    private var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(AppConfig.appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("folders.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let r = try? JSONDecoder().decode([String: FolderRecord].self, from: data) else { return }
        records = r
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }
}

// Стабильные хэши (String.hashValue меняется между запусками).
func fnv32(_ s: String) -> UInt32 {
    var h: UInt32 = 2_166_136_261
    for b in s.utf8 { h ^= UInt32(b); h = h &* 16_777_619 }
    return h
}

func fnv(_ s: String) -> String { String(fnv32(s), radix: 16) }
