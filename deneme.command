#!/bin/bash
# Ekranları sırayla dener: spor (20 sn, istatistiğe yazılmaz), 23:30 ve 23:59 uyarıları.
RUN="$HOME/Applications/SporVakti/run.sh"
echo "3 saniye içinde deneme ekranı açılacak..."
sleep 3
/bin/bash "$RUN" --deneme
/bin/bash "$RUN" --deneme uyku-hazirlik
/bin/bash "$RUN" --deneme uyku
