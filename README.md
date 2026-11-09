# FolderAge — по виду папки понятно, сколько ей лет и когда её трогали

Живёт в строке меню macOS. Папки на рабочем столе:
- **стареют** по дате создания: синий выгорает, бумага желтеет, появляются заломы и рваные края;
- **зарастают** по давности изменений: пыль → одна группа травы → две группы и паутина → мох по всему низу → заросли с грибами и пауком.

Положили или удалили файл — папка снова чистая. Ещё можно «обновить» вручную — папка снова свежая и чистая.

**Скачать:** [последний релиз](https://github.com/toomze/FolderAge/releases/latest) → `FolderAge-x.y.z.dmg`.

Меню: **Настройки…**, **Обновить программу…**, **Выход** (по желанию ещё «Протереть все папки»).

## Сборка (на Mac, 1 минута)

```bash
xcode-select --install        # один раз, если нет Xcode
chmod +x build.sh
./build.sh
open build/FolderAge.app
```

Готовые файлы: `build/FolderAge.app` и `build/FolderAge-1.0.0.dmg`.

При первом запуске macOS спросит доступ к папке «Рабочий стол» — разрешите.

## Сборка через GitHub (без Mac под рукой)

1. Создайте репозиторий и запушьте эту папку.
2. Actions → **Build FolderAge** → Run workflow. DMG появится в артефактах запуска.
3. Новая версия: Releases → **Draft a new release** → тег `v1.0.1` → **Publish release**. Через ~2 минуты workflow соберёт `FolderAge-1.0.1.dmg` и прикрепит его к релизу, а пункт «Обновить программу» у пользователей увидит новую версию.

## Что поменять под себя

`Sources/FolderAge/AppConfig.swift`:
- `telegramURL`, `telegramLabel` — ссылка на фидбек внизу настроек;
- `githubRepo` — `"owner/repo"` для проверки обновлений;
- `Stages` — сроки стадий в днях.

`Resources/Info.plist` — `CFBundleIdentifier` (`com.toomze.folderage`).

## Раздача другим людям

Без подписи Apple скачанное приложение macOS откроет только через правый клик → «Открыть» (или `xattr -dr com.apple.quarantine /Applications/FolderAge.app`).
Чтобы открывалось двойным кликом, нужен Apple Developer ID ($99/год):

```bash
SIGN_IDENTITY="Developer ID Application: Имя (TEAMID)" ./build.sh
xcrun notarytool submit build/FolderAge-1.0.0.dmg --apple-id you@mail.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD --wait
xcrun stapler staple build/FolderAge-1.0.0.dmg
```

## Как это работает

- Иконка ставится стандартным `NSWorkspace.setIcon` — так же, как при вставке картинки в «Свойства» папки. «Вернуть обычные иконки» снимает их.
- **Возраст** — дата создания папки (или дата «омоложения»).
- **Активность** — самая свежая дата изменения/добавления файлов внутри (до 3 уровней вложенности) + изменение списка файлов (ловит удаления). Наша собственная иконка (`Icon\r`) не считается.
- **Вариант зарастания** (A/B/C) закреплён за папкой по хэшу пути, поэтому трава не прыгает между стадиями.
- Папки со своей иконкой не трогаются (настраивается).
- Состояние хранится в `~/Library/Application Support/FolderAge/folders.json`.

Иконки: `Resources/Icons/aXnY[V].png` — X возраст 0…4, Y заброшенность 0…4, V вариант A/B/C.
