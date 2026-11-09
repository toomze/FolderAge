#!/bin/bash
# Сборка FolderAge.app и FolderAge-<версия>.dmg. Нужен Mac с Xcode или Command Line Tools (xcode-select --install).
#   ./build.sh                        — ad-hoc подпись, для себя
#   VERSION=1.2.0 ./build.sh          — задать версию
#   SIGN_IDENTITY="Developer ID Application: Имя (TEAMID)" ./build.sh — подпись Developer ID
#   + APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD — ещё и нотаризация (запуск без предупреждений Gatekeeper)
set -euo pipefail
cd "$(dirname "$0")"

APP=FolderAge
VERSION="${VERSION:-1.0.0}"
BUILD=build
SPARKLE_VERSION=2.9.1
SPARKLE_DIR=.sparkle/$SPARKLE_VERSION
SDK="$(xcrun --show-sdk-path --sdk macosx)"

if [[ ! -d "$SPARKLE_DIR/Sparkle.framework" ]]; then
  echo "▸ Загрузка Sparkle ${SPARKLE_VERSION}…"
  mkdir -p "$SPARKLE_DIR"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
    | tar -xJ -C "$SPARKLE_DIR"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "▸ Компиляция (arm64 + x86_64)…"
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 \
    -target "$ARCH-apple-macos13.0" -sdk "$SDK" \
    -F "$SPARKLE_DIR" \
    -framework AppKit -framework SwiftUI -framework Combine -framework ServiceManagement -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    Sources/FolderAge/*.swift -o "$BUILD/$APP-$ARCH"
done
lipo -create "$BUILD/$APP-arm64" "$BUILD/$APP-x86_64" -output "$BUILD/$APP"

echo "▸ Сборка бандла…"
BUNDLE="$BUILD/$APP.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources" "$BUNDLE/Contents/Frameworks"
cp "$BUILD/$APP" "$BUNDLE/Contents/MacOS/$APP"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$BUNDLE/Contents/Info.plist"
cp -R Resources/Icons "$BUNDLE/Contents/Resources/Icons"
cp -R Resources/Decor "$BUNDLE/Contents/Resources/Decor"
ditto "$SPARKLE_DIR/Sparkle.framework" "$BUNDLE/Contents/Frameworks/Sparkle.framework"
# Приложение не в песочнице — XPC-сервисы Sparkle не нужны.
rm -rf "$BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices"

ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for S in 16 32 128 256 512; do
  sips -z $S $S Resources/AppIcon.png --out "$ICONSET/icon_${S}x${S}.png" >/dev/null
  sips -z $((S * 2)) $((S * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${S}x${S}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "▸ Подпись…"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  SIGN=(--force --options runtime --timestamp --sign "$SIGN_IDENTITY")
else
  SIGN=(--force --sign -)
fi
FW="$BUNDLE/Contents/Frameworks/Sparkle.framework"
codesign "${SIGN[@]}" "$FW/Versions/B/Autoupdate"
codesign "${SIGN[@]}" "$FW/Versions/B/Updater.app"
codesign "${SIGN[@]}" "$FW"
codesign "${SIGN[@]}" "$BUNDLE"
codesign --verify --deep --strict "$BUNDLE"

notarize() {
  local file="$1" out status sid
  out=$(xcrun notarytool submit "$file" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" --wait --output-format json)
  echo "$out"
  status=$(printf '%s' "$out" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')
  sid=$(printf '%s' "$out" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')
  if [[ "$status" != "Accepted" ]]; then
    echo "✗ Нотаризация не прошла ($status). Журнал Apple:"
    xcrun notarytool log "$sid" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" || true
    exit 1
  fi
}

NOTARIZE=0
if [[ -n "${SIGN_IDENTITY:-}" && -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  NOTARIZE=1
  echo "▸ Нотаризация приложения…"
  ditto -c -k --keepParent "$BUNDLE" "$BUILD/$APP-notarize.zip"
  notarize "$BUILD/$APP-notarize.zip"
  xcrun stapler staple "$BUNDLE"
  rm -f "$BUILD/$APP-notarize.zip"
fi

echo "▸ Образ диска…"
mkdir -p "$BUILD/dmg"
ditto "$BUNDLE" "$BUILD/dmg/$APP.app"
ln -s /Applications "$BUILD/dmg/Applications"
hdiutil create -volname "$APP" -srcfolder "$BUILD/dmg" -ov -format UDZO "$BUILD/$APP-$VERSION.dmg" >/dev/null

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$BUILD/$APP-$VERSION.dmg"
fi
if [[ "$NOTARIZE" == 1 ]]; then
  echo "▸ Нотаризация образа диска…"
  notarize "$BUILD/$APP-$VERSION.dmg"
  xcrun stapler staple "$BUILD/$APP-$VERSION.dmg"
  spctl --assess --type execute --verbose=2 "$BUNDLE" || true
  spctl --assess --type open --context context:primary-signature --verbose=2 "$BUILD/$APP-$VERSION.dmg" || true
fi

echo "✓ Готово: $BUNDLE и $BUILD/$APP-$VERSION.dmg"
