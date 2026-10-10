#!/bin/bash
# Saat başı hatırlatmayı kaldırır. Spor geçmişin (gecmis.csv) silinmez.
LABEL="com.sporvakti.reminder"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/SporVakti"
echo "✅ Spor Vakti kaldırıldı."
echo "   Geçmişin burada duruyor: ~/Library/Application Support/SporVakti"
