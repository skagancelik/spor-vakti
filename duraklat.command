#!/bin/bash
# Hatırlatıcıyı geçici durdurur ya da yeniden açar.
F="$HOME/Library/Application Support/SporVakti/DURAKLAT"
mkdir -p "$(dirname "$F")"
if [ -f "$F" ]; then rm "$F"; echo "✅ Spor Vakti yeniden AÇIK."
else touch "$F"; echo "⏸  Spor Vakti DURAKLATILDI. Devam için tekrar çalıştır."; fi
