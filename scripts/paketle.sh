#!/bin/bash
# Xcode gerektirmeyen hazır sürüm paketi: Intel + Apple Silicon (universal) ikili dosya,
# müzikler ve .command betikleri tek zip'te. GitHub Releases'a yüklenir.
# Kullanım: scripts/paketle.sh 1.0.0   →   dist/SporVakti-1.0.0.zip
set -e
VER="${1:?sürüm ver: scripts/paketle.sh 1.0.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
PKG="$OUT/SporVakti-$VER"
rm -rf "$PKG" "$PKG.zip"
mkdir -p "$PKG/bin" "$PKG/scripts"

echo "-- derleniyor (arm64 + x86_64, macOS 13+)"
swiftc -O -target arm64-apple-macos13 -o "$OUT/spor-vakti-arm64" "$ROOT/src/main.swift"
swiftc -O -target x86_64-apple-macos13 -o "$OUT/spor-vakti-x86_64" "$ROOT/src/main.swift"
lipo -create -output "$PKG/bin/spor-vakti" "$OUT/spor-vakti-arm64" "$OUT/spor-vakti-x86_64"
rm "$OUT/spor-vakti-arm64" "$OUT/spor-vakti-x86_64"
codesign --force --sign - "$PKG/bin/spor-vakti"   # ad-hoc imza (Apple Silicon'da çalışması için gerekli)

echo "-- dosyalar kopyalanıyor"
cp "$ROOT/scripts/run.sh" "$PKG/scripts/"
cp -R "$ROOT/muzik" "$PKG/muzik"
cp "$ROOT"/*.command "$ROOT/README.md" "$ROOT/LICENSE" "$PKG/"
chmod +x "$PKG"/*.command "$PKG/scripts/run.sh" "$PKG/bin/spor-vakti"

(cd "$OUT" && ditto -c -k --norsrc --noextattr --keepParent "SporVakti-$VER" "SporVakti-$VER.zip")
rm -rf "$PKG"
echo "✅ $OUT/SporVakti-$VER.zip"
