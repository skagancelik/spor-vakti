#!/bin/bash
# launchd tarafından 5 dakikada bir ve 23:59'da çağrılır.
# Koşulları kontrol eder, uygunsa ilgili ekranı açar.
# Kullanım: run.sh                         (otomatik, saate göre karar verir)
#           run.sh --deneme                (koşulsuz, 20 sn'lik kayıtsız spor denemesi)
#           run.sh --deneme uyku-hazirlik  (koşulsuz gece uyarısı denemesi; "uyku" da olur)
APP_DIR="$HOME/Applications/SporVakti"
DATA_DIR="$HOME/Library/Application Support/SporVakti"
BIN="$APP_DIR/spor-vakti"
LOG="$DATA_DIR/olaylar.log"
mkdir -p "$DATA_DIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" >> "$LOG"; }

ARGS=("$@")
if [ "$1" != "--deneme" ]; then
  if [ -f "$DATA_DIR/DURAKLAT" ]; then log "atlandı: duraklatılmış"; exit 0; fi

  HOUR=$((10#$(date +%H))); MIN=$((10#$(date +%M)))

  # Erteleme: her "5 dk ertele" o günün saat başı düzenini 5 dk kaydırır
  # (14:00 → 14:05 ertelenirse sonraki 15:05'te gelir). Ertesi gün sıfırlanır.
  SHIFT=0
  if [ -f "$DATA_DIR/erteleme" ]; then
    IFS=, read -r SDAY SMIN < "$DATA_DIR/erteleme"
    if [ "$SDAY" = "$(date +%Y-%m-%d)" ] && [[ "$SMIN" =~ ^[0-9]+$ ]]; then SHIFT=$((SMIN % 60)); fi
  fi
  # launchd 5 dakikada bir çağırır; yalnızca o saatin spor dakikasındaysak devam et
  DELTA=$(( (MIN - SHIFT + 60) % 60 ))

  if [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 30 ] && [ "$MIN" -lt 35 ]; then
    ARGS=(uyku-hazirlik)
  elif [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 59 ]; then
    ARGS=(uyku)
  elif [ "$DELTA" -ge 5 ]; then
    exit 0  # spor dakikası değil (sessizce çık, log şişmesin)
  elif [ "$HOUR" -lt 7 ]; then
    log "atlandı: gece (spor uyarısı 07:00'den önce gösterilmez)"; exit 0
  elif [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 30 ]; then
    log "atlandı: gece uyarısı saati (:$MIN)"; exit 0
  fi

  # Zoom ekran paylaşırken CptHost süreci çalışır — karşı taraf uyarıyı görmesin
  if pgrep -x CptHost >/dev/null 2>&1; then
    log "atlandı: Zoom ekran paylaşımı"; exit 0
  fi
  # (Mikrofon kullanımı ve paylaşım pencereleri uygulamanın kendisinde kontrol edilir.)

  if pgrep -x ScreenSaverEngine >/dev/null 2>&1 || pgrep -f legacyScreenSaver >/dev/null 2>&1; then
    log "atlandı: ekran koruyucu açık"; exit 0
  fi

  if ioreg -n Root -d1 -a 2>/dev/null | grep -q "CGSSessionScreenIsLocked"; then
    log "atlandı: ekran kilitli"; exit 0
  fi

  # 10 dakikadan uzun süredir klavye/fare kullanılmıyorsa zaten masada değilsin
  IDLE=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
  if [ -n "$IDLE" ] && [ "$IDLE" -gt 600 ]; then
    log "atlandı: ${IDLE}sn'dir klavye/fare hareketi yok"; exit 0
  fi
fi

if pgrep -x spor-vakti >/dev/null 2>&1; then log "atlandı: ekran zaten açık"; exit 0; fi
if [ ! -x "$BIN" ]; then log "HATA: $BIN yok — önce kur.command çalıştır"; exit 1; fi

log "gösteriliyor ${ARGS[*]}"
"$BIN" "${ARGS[@]}" >> "$LOG" 2>&1
log "kapandı (çıkış=$?)"
