# Spor Vakti

**[Türkçe](#türkçe) · [English](#english)**

![Spor vakti](docs/1-spor-vakti.png)

---

## Türkçe

Bilgisayar başında saatler geçiyor. **Spor Vakti**, her saat başı ekranı kaplar ve tek bir şey söyler: *Spor vakti.*

Sana ne yapacağını söylemez. Ama sana sorar: **gerçekten yapıyor musun, yoksa pas mı geçiyorsun?** Pas geçersen o gün kaç kez pas geçtiğini ve kaç dakika spordan mahrum kaldığını söyler. Kaçamak yok.

### Nasıl çalışır

| | |
|---|---|
| ![Soru](docs/1-spor-vakti.png) | **Saat başı (07:00–23:00, aralık ayarlanabilir):** Tam ekran "Spor vakti." Bugünkü durumun altta: seans, dakika, pas. |
| | **Şimdi olmuyorsa:** **5 dk ertele** (ya da `E`). Pas sayılmaz; uyarı 5 dk sonra gelir ve o günün düzeni de 5 dk kayar (14:00 ertelendiyse 14:05, sonraki 15:05). Her erteleme 5 dk daha kaydırır; ertesi gün saat başına döner. |
| ![Emin misin](docs/2-emin-misin.png) | **Pas geçmek istersen:** "Bugün 2. pas olacak. Bugün toplam 20 dakika spordan mahrum kalacaksın." Kutuya **evet** yazınca **Pas geç** düğmesi açılır. **Spora başla** her zaman orada. |
| ![Seans](docs/3-seans.png) | **Başlıyorum dersen:** 10 dakikalık (ayarlanabilir) geri sayım; müzik açıksa süre boyunca çalar. Erken bitirirsen eksik kalan dakikalar da sayılır. **Küçült · müzik aç** (ya da `M`) ile ekran köşede küçük bir sayaca dönüşür: müzik açabilir, bilgisayarı kullanabilirsin; seans sürer, pas sayılmaz. Süre bitince tam ekran geri gelir. |
| ![Tamamlandı](docs/4-tamamlandi.png) | **Bitince:** Bugün kaçıncı seans olduğu ve toplam spor süresi. |
| ![Uyku hazırlığı](docs/5-uyku-hazirlik.png) | **23:30:** "Uyumak için hazırlıklarını yap." |
| ![Uyku vakti](docs/6-uyku-vakti.png) | **23:59:** "Uyku vakti." Gece uyarıları yalnızca **Tamam** ile kapanır. |

### Ne zaman görünmez

- **Görüşmedeyken:** Bir uygulama mikrofonu kullanıyorsa (Zoom, Google Meet, Teams…) uyarı açılmaz.
- **Ekran paylaşırken:** Zoom paylaşımı ya da Chrome'un paylaşım çubuğu varsa uyarı açılmaz. Pencereler ayrıca ekran yakalamadan hariç tutulacak şekilde işaretlenir. Karşı taraf görmez.
- Ekran kilitliyken, ekran koruyucu açıkken, 10 dakikadan uzun süredir klavye ya da fare kullanılmıyorsa.
- Bilgisayar uykudan geç uyandıysa (uyarı dakikasının üzerinden 5 dakika geçtiyse).
- Gece 00:00–07:00 arası spor uyarısı yok.
- Duraklatılmışken.

5 dakika içinde cevap verilmezse seans **cevapsız** (pas) sayılır.

### Kurulum

macOS ve Xcode Command Line Tools (`swiftc`) gerekir.

```bash
git clone https://github.com/skagancelik/spor-vakti.git
cd spor-vakti
./kur.command
```

Ya da Finder'da dosyalara çift tıkla:

| Dosya | Ne yapar |
|---|---|
| `kur.command` | Derler, kurar, zamanlayıcıyı başlatır. Güncelleme için de tekrar çalıştır. |
| `deneme.command` | Ekranları dener (20 sn'lik spor + iki gece uyarısı). İstatistiğe yazılmaz. |
| `rapor.command` | Son 7 günün tablosu: seans, spor dakikası, pas, mahrum kalınan dakika. |
| `ayarlar.command` | Ayar ekranı: spor aralığı, spor süresi, müzik. |
| `duraklat.command` | Geçici olarak durdurur / yeniden açar. |
| `kaldir.command` | Kaldırır. Geçmiş verin silinmez. |

### Ayarlar

`ayarlar.command` ile açılan ekrandan:

- **Spor aralığı:** kaç saat kaç dakikada bir (5 dk adımlarla, en az 15 dk). Varsayılan **1 saat**. Uyarılar 07:00'den başlar ve bu aralıkla tekrar eder (ör. 1 saat 30 dk → 07:00, 08:30, 10:00…).
- **Spor süresi:** 1–60 dakika. Varsayılan **10 dakika**.
- **Müzik:** açıksa spor başlayınca `muzik/` klasöründeki parçalar karışık sırayla çalar, süre bitince (ya da erken bitirince) durur. Repoya eklenen parçalar `kur.command` ile kurulur; repoyu indiren herkes kullanır. Yalnızca kendine ait parçaları `~/Library/Application Support/SporVakti/muzik` klasörüne koyabilirsin (ayar ekranındaki **Müzik klasörünü aç**).

Ayarlar `~/Library/Application Support/SporVakti/ayarlar` dosyasında durur. `SPOR_VAKTI_DK` ortam değişkeni seans süresinin önüne geçer.

### Gizlilik

- **İnternete hiç bağlanmaz.** Kodda tek bir ağ çağrısı yok.
- Geçmiş yalnızca kendi bilgisayarında, `~/Library/Application Support/SporVakti/gecmis.csv` içinde durur.
- Mikrofon kontrolü **ses dinlemez.** macOS'a yalnızca "şu an mikrofonu kullanan bir uygulama var mı?" diye sorar.

---

## English

Hours slip by at the desk. **Spor Vakti** ("workout time" in Turkish) takes over your screen at the top of every hour and says just one thing: *Time to move.*

It doesn't tell you what to do. It asks: **are you actually doing it, or skipping?** Skip, and it tells you how many times you've skipped today and how many minutes of exercise you've missed. No hiding.

### How it works

- **Every hour (07:00–23:00, interval configurable):** a full-screen "Spor vakti." prompt with today's tally (sessions, minutes, skips).
- **Not now?** **5 dk ertele** (or `E`) snoozes 5 minutes without counting as a skip, and shifts the rest of the day's schedule by 5 minutes too (snooze 14:00 → 14:05, next one at 15:05). Each snooze adds another 5; the next day starts on the hour again.
- **Skip?** A confirmation screen shows the cost ("This will be skip #2 today, 20 minutes missed"). Typing **evet** ("yes") unlocks the **Pas geç** (Skip) button; **Spora başla** (Start) is always there. Your choice is recorded explicitly.
- **Start?** A 10-minute countdown. Ending early still counts the missing minutes. **Küçült · müzik aç** (or `M`) shrinks it to a small corner timer so you can put on music or use the computer; the session keeps running and is not a skip. It returns to full screen when time is up.
- **Done:** today's session count and total exercise time.
- **23:30:** "Get ready for bed." **23:59:** "Bedtime." Night notices close only with **Tamam** (OK).

### When it stays hidden

- **On a call:** if any app is capturing the microphone (Zoom, Google Meet, Teams…).
- **While screen sharing:** Zoom sharing or Chrome's sharing bar detected. The windows are also excluded from screen capture where supported, so the people you share with don't see the reminder.
- Screen locked, screensaver running, or no keyboard or mouse activity for 10+ minutes.
- Late wake from sleep, quiet hours (00:00–07:00 for workout prompts), or paused.

No answer within 5 minutes counts as a skip.

### Install

Requires macOS and Xcode Command Line Tools (`swiftc`).

```bash
git clone https://github.com/skagancelik/spor-vakti.git
cd spor-vakti
./kur.command
```

The `.command` scripts can also be double-clicked in Finder: `kur` (install/update), `deneme` (try the screens, nothing is recorded), `rapor` (7-day report), `ayarlar` (settings), `duraklat` (pause/resume), `kaldir` (uninstall; history is kept).

`ayarlar.command` (settings) lets you pick the workout interval (hours + minutes, 5-minute steps, at least 15 min; default 1 hour, counted from 07:00), the session length (1–60 min; default 10), and whether to play music during the session. Music comes from the repo's `muzik/` folder (installed by `kur.command`) plus your personal `~/Library/Application Support/SporVakti/muzik`; it plays shuffled while the session runs and stops when it ends.

### Privacy

- **No network access at all.** No network code in the codebase.
- History stays on your machine only: `~/Library/Application Support/SporVakti/gecmis.csv`.
- The microphone check **never listens to audio.** It only asks macOS whether some app is currently capturing input.

---

## Lisans / License

[MIT](LICENSE)
