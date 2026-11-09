import SwiftUI

enum SettingsTab: Hashable { case folders, settings }

struct SettingsView: View {
    @State private var tab: SettingsTab = .folders

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                FoldersTab()
                    .tabItem { Label("Папки", systemImage: "folder") }
                    .tag(SettingsTab.folders)
                PrefsTab()
                    .tabItem { Label("Настройки", systemImage: "gearshape") }
                    .tag(SettingsTab.settings)
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
                Button("Обновить все") { engine.refreshAll() }
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
            Button("Обновить") { engine.refresh(info.id) }
                .disabled(info.excluded || info.foreignIcon)
            Menu {
                Button("Обновить") { engine.refresh(info.id) }
                    .disabled(info.excluded || info.foreignIcon)
                Button(info.excluded ? "Снова применять эффекты" : "Не трогать эту папку") {
                    engine.setExcluded(info.id, !info.excluded)
                }
                Divider()
                Button("Показать в Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: info.id)])
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Настройки (вместе с «О программе»)

struct PrefsTab: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text(AppConfig.appName).font(.title2).bold()
                Text("Версия \(Updater.currentVersion)")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("По виду папки понятно, сколько ей лет и когда её трогали: папки стареют, покрываются пылью, паутиной и травой, если ими долго не пользоваться.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .padding(.top, 2)
            }
            .padding(.top, 12)
            Form {
                Toggle("Эффекты включены", isOn: $prefs.enabled)
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in LoginItem.set(value) }
                Toggle("Не трогать папки со своей иконкой", isOn: $prefs.respectCustomIcons)
                Toggle("Проверять обновления автоматически", isOn: $prefs.autoCheckUpdates)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
    }
}
