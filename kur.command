#!/bin/bash
# Spor Vakti kurulumu: derler, ~/Applications/SporVakti altına kopyalar, 5 dakikada bir çalışan LaunchAgent'ı yükler.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Applications/SporVakti"
LABEL="com.sporvakti.reminder"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "=== Spor Vakti kurulumu ==="
mkdir -p "$APP_DIR" "$HOME/Library/LaunchAgents"

# Hazır sürüm (GitHub Releases zip'i) bin/ içinde derlenmiş dosyayla gelir: Xcode gerekmez.
# Repodan kuruluyorsa kaynak koddan derlenir (Xcode Command Line Tools gerekir).
if [ -x "$SRC/bin/spor-vakti" ]; then
  echo "-- hazır sürüm kuruluyor"
  cp "$SRC/bin/spor-vakti" "$APP_DIR/spor-vakti"
else
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "❌ Derleyici yok. İki yol var:"
    echo "   1) Hazır sürümü indir: https://github.com/skagancelik/spor-vakti/releases/latest"
    echo "   2) Xcode Command Line Tools kur:  xcode-select --install"
    exit 1
  fi
  echo "-- derleniyor"
  /usr/bin/swiftc -O -o "$APP_DIR/spor-vakti" "$SRC/src/main.swift"
fi
cp "$SRC/scripts/run.sh" "$APP_DIR/run.sh"
# Spor sırasında çalan müzikler: repodaki parçaları kopyala, kullanıcının eklediklerine dokunma
mkdir -p "$APP_DIR/muzik"
cp "$SRC"/muzik/* "$APP_DIR/muzik/" 2>/dev/null || true
chmod +x "$APP_DIR/spor-vakti" "$APP_DIR/run.sh"
# İnternetten indirilen dosyalardaki karantina işaretini kaldır (launchd'nin çalıştırabilmesi için)
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true

echo "-- LaunchAgent yazılıyor"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$APP_DIR/run.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Minute</key><integer>0</integer></dict>
    <dict><key>Minute</key><integer>5</integer></dict>
    <dict><key>Minute</key><integer>10</integer></dict>
    <dict><key>Minute</key><integer>15</integer></dict>
    <dict><key>Minute</key><integer>20</integer></dict>
    <dict><key>Minute</key><integer>25</integer></dict>
    <dict><key>Minute</key><integer>30</integer></dict>
    <dict><key>Minute</key><integer>35</integer></dict>
    <dict><key>Minute</key><integer>40</integer></dict>
    <dict><key>Minute</key><integer>45</integer></dict>
    <dict><key>Minute</key><integer>50</integer></dict>
    <dict><key>Minute</key><integer>55</integer></dict>
    <dict><key>Hour</key><integer>23</integer><key>Minute</key><integer>59</integer></dict>
  </array>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PL

# bootout eşzamansızdır: eski kayıt kalkana kadar birkaç kez dene
yukle() { launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true
  for i in 1 2 3 4 5; do launchctl bootstrap "gui/$(id -u)" "$2" 2>/dev/null && return 0; sleep 1; done
  launchctl bootstrap "gui/$(id -u)" "$2"; }
yukle "$LABEL" "$PLIST"

echo "-- menü çubuğu simgesi"
MLABEL="com.sporvakti.menu"
MPLIST="$HOME/Library/LaunchAgents/$MLABEL.plist"
cat > "$MPLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$MLABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_DIR/spor-vakti</string>
    <string>menu</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PL
yukle "$MLABEL" "$MPLIST"
echo "✅ Kuruldu. Spor uyarıları ayarladığın saatlerde gelir (varsayılan 07:00–23:00, saat başı), uyku uyarıları 23:30 ve 23:59'da."
echo "   Menü çubuğundaki koşan adam simgesi: sonraki spor, duraklat, ayarlar, rapor."
echo "   Denemek için: deneme.command"
