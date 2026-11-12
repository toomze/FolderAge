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
                if AppConfig.clapsURL != nil { ClapButton() }
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            DecorStrip()
        }
        .frame(width: 620, height: 680)
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
    @ObservedObject var prefs = Prefs.shared

    private var canPickOrnament: Bool { prefs.enabled && prefs.overgrowthOn && !info.excluded && !info.foreignIcon }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                if canPickOrnament {
                    Button { engine.cycleOrnament(info.id, -1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                        .help("Предыдущее украшение")
                }
                Image(nsImage: engine.thumbnail(info))
                    .resizable()
                    .frame(width: 40, height: 40)
                if canPickOrnament {
                    Button { engine.cycleOrnament(info.id, 1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                        .help("Следующее украшение")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).fontWeight(.medium).lineLimit(1)
                Text(info.subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if info.excluded {
                Button("Оформлять эту папку") { engine.setExcluded(info.id, false) }
                    .help("Снова менять иконку этой папки по теме")
            } else if info.foreignIcon {
                Button("Оформить эту папку") { engine.refresh(info.id) }
                    .help("Заменить иконку этой папки на иконку темы")
            } else {
                Button("Не трогать эту папку") { engine.setExcluded(info.id, true) }
                    .help("Вернуть этой папке обычную иконку и больше её не менять")
            }
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
                Toggle("Тема включена", isOn: $prefs.enabled)
                Toggle("Случайные украшения", isOn: $prefs.overgrowthOn)
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
struct ClapButton: View {
    @ObservedObject var claps = ClapStore.shared
    @State private var iconScale: CGFloat = 1
    @State private var iconAngle: Double = 0
    @State private var countLift: CGFloat = 0
    @State private var bubbleShown = false
    @State private var bubbleLift: CGFloat = 6
    @State private var bubbleToken = 0

    var body: some View {
        Button { clap() } label: {
            HStack(spacing: 6) {
                Image(systemName: claps.mine > 0 ? "hands.clap.fill" : "hands.clap")
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconAngle))
                Text("Похлопать")
                if claps.total > 0 {
                    Text("\(claps.total)").monospacedDigit().foregroundColor(.secondary).offset(y: countLift)
                }
            }
        }
        .disabled(!claps.canClap)
        .help(claps.canClap ? "Твоих хлопков: \(claps.mine) из \(ClapStore.maxMine)" : "Ты уже хлопнул \(ClapStore.maxMine) раз — спасибо!")
        .overlay(alignment: .topLeading) {
            // Всплывающий кружок с числом своих хлопков, как в Medium.
            Text("+\(claps.mine)")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .frame(minWidth: 30, minHeight: 30)
                .background(Capsule().fill(Color.accentColor))
                .fixedSize()
                .offset(x: 2, y: -34 + bubbleLift)
                .opacity(bubbleShown ? 1 : 0)
                .allowsHitTesting(false)
        }
        .onAppear { claps.refreshIfStale() }
    }

    private func clap() {
        guard claps.canClap else { return }
        claps.clap()
        // Руки подпрыгивают.
        withAnimation(.easeOut(duration: 0.13)) { iconScale = 1.45; iconAngle = -14; countLift = -3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { iconScale = 1; iconAngle = 0; countLift = 0 }
        }
        // Кружок всплывает, держится и тает.
        bubbleToken += 1
        let token = bubbleToken
        bubbleLift = 6
        withAnimation(.easeOut(duration: 0.18)) { bubbleShown = true; bubbleLift = -8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard token == bubbleToken else { return }
            withAnimation(.easeIn(duration: 0.3)) { bubbleShown = false; bubbleLift = -22 }
        }
    }
}

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
