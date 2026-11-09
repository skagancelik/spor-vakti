#!/bin/bash
# Saat başı hatırlatmayı kaldırır. Spor geçmişin (gecmis.csv) silinmez.
for LABEL in com.sporvakti.reminder com.sporvakti.menu; do
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
done
rm -rf "$HOME/Applications/SporVakti" "$HOME/Applications/Spor Vakti.app"
echo "✅ Spor Vakti kaldırıldı."
echo "   Geçmişin burada duruyor: ~/Library/Application Support/SporVakti"
