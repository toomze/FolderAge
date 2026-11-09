#!/bin/bash
# Подписывает DMG ключом Sparkle и пишет build/appcast.xml для релиза.
#   SPARKLE_PRIVATE_KEY=... VERSION=1.0.1 ./make_appcast.sh  [файл_с_заметками]
set -euo pipefail
cd "$(dirname "$0")"

APP=FolderAge
REPO=toomze/FolderAge
VERSION="${VERSION:?VERSION не задан}"
NOTES_FILE="${1:-}"
SPARKLE_VERSION=2.9.1
DMG="build/$APP-$VERSION.dmg"

SIG=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | ".sparkle/$SPARKLE_VERSION/bin/sign_update" --ed-key-file - "$DMG")
# SIG выглядит как: sparkle:edSignature="..." length="..."

NOTES=""
if [[ -n "$NOTES_FILE" && -s "$NOTES_FILE" ]]; then
  NOTES=$(python3 -c 'import html,sys; print("<br>".join(html.escape(l) for l in open(sys.argv[1]).read().strip().splitlines()))' "$NOTES_FILE")
fi

cat > build/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP</title>
    <item>
      <title>Версия $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<div style="font-family:-apple-system;font-size:13px">${NOTES:-Новая версия $APP $VERSION.}</div>]]></description>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/$APP-$VERSION.dmg" type="application/octet-stream" $SIG />
    </item>
  </channel>
</rss>
EOF
echo "✓ build/appcast.xml"
