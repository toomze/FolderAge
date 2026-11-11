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
            HStack(spacing: 6) {
                Text("Идея, баг или просто спасибо?")
                    .foregroundColor(.secondary)
                Link("Написать в Telegram \(AppConfig.telegramLabel)", destination: AppConfig.telegramURL)
                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            DecorStrip()
        }
        .frame(width: 620, height: 640)
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
                Button("Вернуть обычные иконки") {
                    // Выключаем эффекты, иначе следующая проверка снова поставит иконки.
                    prefs.enabled = false
                    engine.restoreAll(rescan: false)
                }
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
                .disabled(info.excluded)
                .help(info.foreignIcon ? "Заменить иконку папки на иконку темы" : "Папка снова свежая — первая стадия темы")
            Menu {
                Button(info.foreignIcon ? "Оформить эту папку" : "Обновить") { engine.refresh(info.id) }
                    .disabled(info.excluded)
                if info.excluded {
                    Button("Снова оформлять эту папку") { engine.setExcluded(info.id, false) }
                } else {
                    Button("Не трогать эту папку") { engine.setExcluded(info.id, true) }
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

// MARK: - Настройки

struct PrefsTab: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Тема").font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
            HStack(spacing: 10) {
                ForEach(Theme.allCases) { t in ThemeCard(theme: t, selected: prefs.theme == t) { prefs.theme = t } }
            }
            Text(prefs.theme.summary)
                .font(.caption)
                .foregroundColor(.secondary)
            Form {
                Toggle("Эффекты включены", isOn: $prefs.enabled)
                Toggle("Загружать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in LoginItem.set(value) }
                Toggle("Не трогать папки со своей иконкой", isOn: $prefs.respectCustomIcons)
                Toggle("Проверять обновления автоматически", isOn: $prefs.autoCheckUpdates)
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            .scrollDisabled(true)
            .padding(.horizontal, -20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct ThemeCard: View {
    let theme: Theme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ThemePreview(theme: theme)
                    .frame(width: 112, height: 112)
                Text(theme.title)
                    .font(.callout)
                    .fontWeight(selected ? .bold : .medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Тема \(theme.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ThemePreview: View {
    let theme: Theme

    var body: some View {
        if let img = DecayEngine.shared.image("\(theme.rawValue)/\(theme.previewKey)") {
            Image(nsImage: img)
                .interpolation(theme.isPixelArt ? .none : .high)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "folder").font(.largeTitle)
        }
    }
}

/// Узкая полоса «зарастания» текущей темы по нижнему краю окна.
struct DecorStrip: View {
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        GeometryReader { geo in
            if let url = Bundle.main.url(forResource: "\(prefs.theme.rawValue)_strip", withExtension: "png", subdirectory: "Decor"),
               let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .interpolation(prefs.theme.isPixelArt ? .none : .high)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
                    .clipped()
            }
        }
        .frame(height: 50)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
