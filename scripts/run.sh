#!/bin/bash
# launchd tarafından 5 dakikada bir ve 23:59'da çağrılır.
# Koşulları kontrol eder, uygunsa ilgili ekranı açar.
# Kullanım: run.sh                         (otomatik, saate göre karar verir)
#           run.sh --deneme                (koşulsuz, 20 sn'lik kayıtsız spor denemesi)
#           run.sh --deneme uyku-hazirlik  (koşulsuz gece uyarısı denemesi; "uyku" da olur)
APP_DIR="$HOME/Applications/SporVakti"
DATA_DIR="${SPOR_VAKTI_DATA:-$HOME/Library/Application Support/SporVakti}"
BIN="$APP_DIR/spor-vakti"
LOG="$DATA_DIR/olaylar.log"
mkdir -p "$DATA_DIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" >> "$LOG"; }

ARGS=("$@")
# --kuru: yalnızca kararı yazar, ekran açmaz (SPOR_VAKTI_SIMDI=SS:DD ile saat verilebilir; test için)
KURU=0
if [ "$1" = "--kuru" ]; then KURU=1; ARGS=(); shift; fi
karar() { if [ "$KURU" = 1 ]; then echo "$*"; exit 0; fi; }

if [ "$1" != "--deneme" ]; then
  if [ -f "$DATA_DIR/DURAKLAT" ]; then karar "atla: duraklatılmış"; log "atlandı: duraklatılmış"; exit 0; fi
  # Menüden "1 saat / bugünlük duraklat": duraklat_bitis içinde bitiş zamanı (epoch)
  if [ -f "$DATA_DIR/duraklat_bitis" ]; then
    B=$(tr -dc '0-9' < "$DATA_DIR/duraklat_bitis")
    if [ -n "$B" ] && [ "$(date +%s)" -lt "$B" ]; then karar "atla: duraklatılmış (süreli)"; log "atlandı: duraklatılmış (süreli)"; exit 0; fi
    rm -f "$DATA_DIR/duraklat_bitis"
  fi

  NOW_HM="${SPOR_VAKTI_SIMDI:-$(date +%H:%M)}"
  HOUR=$((10#${NOW_HM%:*})); MIN=$((10#${NOW_HM#*:}))
  NOW=$(( HOUR * 60 + MIN ))

  # Ayarlar (ayarlar.command ya da spor ekranındaki Ayarlar düğmesi yazar)
  ayar() {  # ayar <anahtar> <varsayılan>
    local v=""
    [ -f "$DATA_DIR/ayarlar" ] && v=$(sed -n "s/^$1=\([0-9][0-9]*\)$/\1/p" "$DATA_DIR/ayarlar" | tail -1)
    if [ -n "$v" ]; then echo $((10#$v)); else echo "$2"; fi
  }
  INTERVAL=$(ayar aralik_dk 60);   [ "$INTERVAL" -lt 15 ] && INTERVAL=60
  START=$(ayar baslangic_dk 420)   # 07:00
  END=$(ayar bitis_dk 1380)        # 23:00 (dahil)
  SLEEP=$(ayar uyku_uyarisi 1)
  if [ "$START" -ge 1440 ] || [ "$END" -ge 1440 ] || [ "$END" -le "$START" ]; then START=420; END=1380; fi

  # Erteleme: her "5 dk ertele" o günün düzenini 5 dk kaydırır
  # (14:00 → 14:05 ertelenirse sonraki 15:05'te gelir). Ertesi gün sıfırlanır.
  SHIFT=0
  if [ -f "$DATA_DIR/erteleme" ]; then
    IFS=, read -r SDAY SMIN < "$DATA_DIR/erteleme"
    if [ "$SDAY" = "$(date +%Y-%m-%d)" ] && [[ "$SMIN" =~ ^[0-9]+$ ]]; then SHIFT=$((10#$SMIN % INTERVAL)); fi
  fi
  # Uyarılar başlangıç saatinden itibaren INTERVAL dakikada bir gelir.
  # launchd 5 dakikada bir çağırır; yalnızca spor dakikasındaysak devam et.
  ELAPSED=$(( NOW - START - SHIFT ))
  DELTA=$(( (ELAPSED % INTERVAL + INTERVAL) % INTERVAL ))

  if [ "$SLEEP" = 1 ] && [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 30 ] && [ "$MIN" -lt 35 ]; then
    ARGS=(uyku-hazirlik)
  elif [ "$SLEEP" = 1 ] && [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 59 ]; then
    ARGS=(uyku)
  elif [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 59 ]; then
    karar "sessiz"; exit 0  # 23:59 yalnızca uyku uyarısı içindir
  elif [ "$DELTA" -ge 5 ]; then
    karar "sessiz"; exit 0  # spor dakikası değil (sessizce çık, log şişmesin)
  elif [ "$NOW" -lt "$START" ]; then
    karar "atla: başlangıçtan önce"; log "atlandı: spor saatleri dışında (başlangıçtan önce)"; exit 0
  elif [ "$NOW" -ge $(( END + 5 )) ]; then
    karar "atla: bitişten sonra"; log "atlandı: spor saatleri dışında (bitişten sonra)"; exit 0
  elif [ "$SLEEP" = 1 ] && [ "$HOUR" -eq 23 ] && [ "$MIN" -ge 30 ]; then
    karar "atla: gece uyarısı saati"; log "atlandı: gece uyarısı saati (:$MIN)"; exit 0
  fi
  karar "${ARGS[*]:-spor}"

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

# Spor/uyku ekranı zaten açıksa ikinciyi açma (menü simgesi ve ayar penceresi sayılmaz)
if ps -axo args= | grep -E "^$BIN( |$)" | grep -vqE " (menu|ayarlar)$"; then log "atlandı: ekran zaten açık"; exit 0; fi
if [ ! -x "$BIN" ]; then log "HATA: $BIN yok — önce kur.command çalıştır"; exit 1; fi

log "gösteriliyor ${ARGS[*]}"
"$BIN" "${ARGS[@]}" >> "$LOG" 2>&1
log "kapandı (çıkış=$?)"
