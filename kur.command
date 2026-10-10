#!/bin/bash
# Spor Vakti kurulumu: derler, ~/Applications/SporVakti altına kopyalar, saat başı LaunchAgent'ı yükler.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Applications/SporVakti"
LABEL="com.sporvakti.reminder"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "=== Spor Vakti kurulumu ==="
mkdir -p "$APP_DIR" "$HOME/Library/LaunchAgents"

echo "-- derleniyor"
/usr/bin/swiftc -O -o "$APP_DIR/spor-vakti" "$SRC/src/main.swift"
cp "$SRC/scripts/run.sh" "$APP_DIR/run.sh"
chmod +x "$APP_DIR/spor-vakti" "$APP_DIR/run.sh"

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
    <dict><key>Hour</key><integer>23</integer><key>Minute</key><integer>30</integer></dict>
    <dict><key>Hour</key><integer>23</integer><key>Minute</key><integer>59</integer></dict>
  </array>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "✅ Kuruldu. Saat başı (07:00–23:00) spor, 23:30 ve 23:59'da uyku uyarısı gelecek."
echo "   Denemek için: deneme.command"
