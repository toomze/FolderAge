import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralTab().tabItem { Label("Основные", systemImage: "gearshape") }
                FoldersTab().tabItem { Label("Папки", systemImage: "folder") }
                AboutTab().tabItem { Label("О программе", systemImage: "info.circle") }
            }
            .padding(.top, 8)
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "paperplane")
                    .foregroundColor(.secondary)
                Text("Идея, баг или просто спасибо?")
                    .foregroundColor(.secondary)
                Link("Написать в Telegram \(AppConfig.telegramLabel)", destination: AppConfig.telegramURL)
                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 620, height: 600)
    }
}

// MARK: - Основные

struct GeneralTab: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Эффекты включены", isOn: $prefs.enabled)
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in LoginItem.set(value) }
            }
            Section("Что происходит с папками") {
                Toggle("Старение — по дате создания", isOn: $prefs.agingOn)
                Toggle("Пыль, паутина и трава — по давности изменений", isOn: $prefs.overgrowthOn)
                Picker("Скорость времени", selection: $prefs.speed) {
                    ForEach(TimeSpeed.allCases) { Text($0.title).tag($0) }
                }
                Text(prefs.thresholdSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("Протирание") {
                Toggle("Протирание также омолаживает папку", isOn: $prefs.wipeAlsoResetsAge)
                Toggle("Пункт «Протереть все папки» в меню", isOn: $prefs.wipeAllInMenu)
            }
            Section("Поведение") {
                Toggle("Свежие чистые папки оставлять системными", isOn: $prefs.keepFreshSystem)
                Toggle("Не трогать папки со своей иконкой", isOn: $prefs.respectCustomIcons)
                Toggle("Возвращать обычные иконки при выходе", isOn: $prefs.restoreOnQuit)
                Picker("Проверять изменения", selection: $prefs.scanMinutes) {
                    Text("каждые 5 минут").tag(5)
                    Text("каждые 15 минут").tag(15)
                    Text("каждый час").tag(60)
                }
                Toggle("Проверять обновления автоматически", isOn: $prefs.autoCheckUpdates)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Папки

struct FoldersTab: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var engine = DecayEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Где искать папки") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Рабочий стол", isOn: $prefs.watchDesktop)
                    ForEach(prefs.extraRoots, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder")
                            Text(path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button("Убрать") { engine.removeRoot(path) }
                        }
                    }
                    Button("Добавить папку…") { engine.chooseRoot() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            HStack {
                Text("Папки (\(engine.folders.count))").font(.headline)
                Spacer()
                Button("Протереть все") { engine.wipeAll() }
                Button("Вернуть обычные иконки") { engine.restoreAll() }
            }
            if engine.folders.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "folder.badge.questionmark").font(.largeTitle).foregroundColor(.secondary)
                    Text("Папок пока нет. Если вы только что дали доступ к рабочему столу, подождите пару секунд.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(engine.folders) { f in FolderRow(info: f) }
            }
        }
        .padding(20)
    }
}

struct FolderRow: View {
    let info: FolderInfo
    @ObservedObject var engine = DecayEngine.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: engine.thumbnail(info))
                .resizable()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).fontWeight(.medium).lineLimit(1)
                Text(info.subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(info.stageLabel)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            Button("Протереть") { engine.wipe(info.id) }
                .disabled(info.excluded || info.foreignIcon)
            Menu {
                Button("Омолодить (вернуть синий цвет)") { engine.rejuvenate(info.id) }
                Button(info.excluded ? "Снова применять эффекты" : "Не трогать эту папку") {
                    engine.setExcluded(info.id, !info.excluded)
                }
                Divider()
                Button("Показать в Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: info.id)])
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - О программе

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text(AppConfig.appName).font(.title).bold()
            Text("Версия \(Updater.currentVersion)").foregroundColor(.secondary)
            Text("Папки на рабочем столе стареют, покрываются пылью, паутиной и травой, если ими долго не пользоваться. Протрите папку — и она снова чистая.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Проверить обновления") { Updater.check(interactive: true) }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}
