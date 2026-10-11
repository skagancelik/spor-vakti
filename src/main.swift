// Spor Vakti — saat başı tam ekran spor hatırlatıcısı (macOS)
// Hiçbir ağ bağlantısı kurmaz; tüm veriler yerel CSV dosyasında kalır.

import AppKit
import CoreAudio
import Foundation

// MARK: - Ayarlar

let env = ProcessInfo.processInfo.environment
let args = Array(CommandLine.arguments.dropFirst())
let isTrial = args.contains("--deneme")

/// Gece uyarıları: "uyku-hazirlik" (23:30) ve "uyku" (23:59). Yoksa spor akışı.
enum Notice: String { case prepare = "uyku-hazirlik", sleep = "uyku" }
let notice = args.compactMap(Notice.init(rawValue:)).first

/// Bir seansın süresi (dakika). SPOR_VAKTI_DK ile değiştirilebilir.
let SESSION_MIN: Int = max(1, Int(env["SPOR_VAKTI_DK"] ?? "") ?? 10)
/// Deneme modunda seans 20 saniye sürer ve kayıt tutulmaz.
let SESSION_SEC: Double = isTrial ? 20 : Double(SESSION_MIN * 60)
/// Bu süre içinde cevap verilmezse seans "cevapsız" (pas) sayılır.
let ANSWER_TIMEOUT: TimeInterval = isTrial ? 60 : 5 * 60
/// Özet ekranı bu süre sonra kendiliğinden kapanır.
let SUMMARY_SEC: TimeInterval = 10

// MARK: - Kayıt defteri

enum Outcome: String {
    case done = "yapildi", partial = "yarim", skipped = "pas", noAnswer = "cevapsiz"
    var isPass: Bool { self == .skipped || self == .noAnswer }
}

struct Entry {
    let day: String, time: String, outcome: Outcome, planned: Int, doneMin: Int
    var missed: Int { max(0, planned - doneMin) }
}

struct DayStats {
    var sessions = 0, sportMin = 0, passes = 0, missedMin = 0
    init(_ entries: [Entry]) {
        for e in entries {
            if e.outcome.isPass { passes += 1 } else { sessions += 1 }
            sportMin += e.doneMin
            missedMin += e.missed
        }
    }
}

final class Journal {
    let url: URL
    static let header = "tarih,saat,sonuc,plan_dk,yapilan_dk\n"

    init() {
        let base = env["SPOR_VAKTI_DATA"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SporVakti")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("gecmis.csv")
    }

    static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }
    static let dayFmt = fmt("yyyy-MM-dd")
    static let timeFmt = fmt("HH:mm")

    func all() -> [Entry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").dropFirst().compactMap { line in
            let c = line.split(separator: ",").map(String.init)
            guard c.count == 5, let o = Outcome(rawValue: c[2]),
                  let p = Int(c[3]), let d = Int(c[4]) else { return nil }
            return Entry(day: c[0], time: c[1], outcome: o, planned: p, doneMin: d)
        }
    }

    func today() -> [Entry] {
        let d = Journal.dayFmt.string(from: Date())
        return all().filter { $0.day == d }
    }

    func append(_ o: Outcome, planned: Int, done: Int, at date: Date) {
        if isTrial { return }
        let line = "\(Journal.dayFmt.string(from: date)),\(Journal.timeFmt.string(from: date)),\(o.rawValue),\(planned),\(done)\n"
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Journal.header.write(to: url, atomically: true, encoding: .utf8)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8)!)
            try? h.close()
        }
    }
}

let journal = Journal()

// MARK: - Terminal raporu:  spor-vakti rapor

if args.first == "rapor" {
    let all = journal.all()
    let cal = Calendar.current
    print("\nSPOR VAKTİ — son 7 gün\n")
    print("Tarih        Seans  Spor   Pas  Mahrum")
    print("──────────   ─────  ─────  ───  ──────")
    var total = DayStats([])
    for back in (0..<7).reversed() {
        let date = cal.date(byAdding: .day, value: -back, to: Date())!
        let key = Journal.dayFmt.string(from: date)
        let s = DayStats(all.filter { $0.day == key })
        total.sessions += s.sessions; total.sportMin += s.sportMin
        total.passes += s.passes; total.missedMin += s.missedMin
        print(String(format: "%@   %5d  %3d dk  %3d  %3d dk", key, s.sessions, s.sportMin, s.passes, s.missedMin))
    }
    print("──────────   ─────  ─────  ───  ──────")
    print(String(format: "Toplam       %5d  %3d dk  %3d  %3d dk\n", total.sessions, total.sportMin, total.passes, total.missedMin))
    print("Kayıt dosyası: \(journal.url.path)\n")
    exit(0)
}

// MARK: - Görüşme / ekran paylaşımı kontrolü
// Karşı taraf uyarıyı görmesin diye görüşme ya da paylaşım varken hiçbir ekran açılmaz.

/// Mikrofondan ses alan uygulama (Meet, Zoom, Teams… görüşmeleri). Yoksa nil.
/// Süreç bazında bakar; yalnızca hoparlörden ses çalınması görüşme sayılmaz.
func microphoneUser() -> String? {
    let sys = AudioObjectID(kAudioObjectSystemObject)
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr else { return nil }
    var procs = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &procs) == noErr else { return nil }

    for p in procs {
        var input = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput,
                                               mScope: kAudioObjectPropertyScopeGlobal,
                                               mElement: kAudioObjectPropertyElementMain)
        var running: UInt32 = 0
        var rsize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(p, &input, 0, nil, &rsize, &running) == noErr, running != 0 else { continue }
        var bundle = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                                mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var nsize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        _ = AudioObjectGetPropertyData(p, &bundle, 0, nil, &nsize, &name)
        return (name?.takeRetainedValue() as String?) ?? "bilinmeyen uygulama"
    }
    return nil
}

/// Ekranda bir paylaşım çubuğu/penceresi var mı? (Chrome, Zoom…)
/// Pencere adlarını okuyabilmek için ekran kaydı izni gerekir; izin yoksa bu kontrol sessizce atlanır.
func sharingWindowVisible() -> Bool {
    let markers = ["sharing your screen", "sharing a window", "sharing this tab", "stop sharing",
                   "ekranınızı paylaşıyor", "paylaşımı durdur", "paylaşılıyor", "zoom share"]
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
    for w in list {
        let name = (w[kCGWindowName as String] as? String ?? "").lowercased()
        if !name.isEmpty && markers.contains(where: { name.contains($0) }) { return true }
    }
    return false
}

if args.first == "paylasim-kontrol" {
    print("mikrofonu kullanan: \(microphoneUser() ?? "yok")")
    print("paylaşım penceresi: \(sharingWindowVisible())")
    exit(0)
}

if !isTrial {
    if let app = microphoneUser() { print("atlandı: mikrofon kullanımda (\(app))"); exit(0) }
    if sharingWindowVisible() { print("atlandı: ekran paylaşılıyor"); exit(0) }
}

// MARK: - Arayüz yardımcıları

let C_BG1    = NSColor(srgbRed: 0.07, green: 0.10, blue: 0.13, alpha: 1)
let C_BG2    = NSColor(srgbRed: 0.02, green: 0.03, blue: 0.045, alpha: 1)
let C_WHITE  = NSColor(srgbRed: 0.95, green: 0.96, blue: 0.99, alpha: 1)
let C_MUTED  = NSColor(srgbRed: 0.60, green: 0.64, blue: 0.74, alpha: 1)
let C_FAINT  = NSColor(srgbRed: 0.38, green: 0.42, blue: 0.51, alpha: 1)
let C_ACCENT = NSColor(srgbRed: 0.36, green: 0.82, blue: 0.66, alpha: 1)
let C_WARN   = NSColor(srgbRed: 0.97, green: 0.47, blue: 0.42, alpha: 1)
let C_NIGHT  = NSColor(srgbRed: 0.58, green: 0.64, blue: 0.98, alpha: 1)

final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ActionButton: NSButton {
    var handler: (() -> Void)?

    init(_ title: String, primary: Bool, frame: NSRect, fontSize: CGFloat, color: NSColor = C_ACCENT) {
        super.init(frame: frame)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2
        layer?.backgroundColor = primary ? color.cgColor : NSColor(white: 1, alpha: 0.08).cgColor
        layer?.borderWidth = primary ? 0 : 1
        layer?.borderColor = NSColor(white: 1, alpha: 0.16).cgColor
        let ps = NSMutableParagraphStyle(); ps.alignment = .center
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: primary ? C_BG2 : C_WHITE,
            .paragraphStyle: ps
        ])
        target = self
        action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func fire() { handler?() }

    func setActive(_ on: Bool) {
        isEnabled = on
        alphaValue = on ? 1 : 0.3
    }
}

func isYes(_ text: String) -> Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "tr_TR")) == "evet"
}

/// Enter'a basılınca handler'ı çağıran yazı kutusu
final class EntryField: NSTextField {
    var handler: ((String) -> Void)?
    init(frame: NSRect, fontSize: CGFloat) {
        super.init(frame: frame)
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        alignment = .center
        textColor = C_WHITE
        font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        placeholderAttributedString = NSAttributedString(string: "evet", attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: C_FAINT,
            .paragraphStyle: { let ps = NSMutableParagraphStyle(); ps.alignment = .center; return ps }()
        ])
        target = self
        action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError() }
    var onChange: ((String) -> Void)?
    @objc func fire() { handler?(stringValue) }
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        onChange?(stringValue)
    }
}

func label(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor,
           _ frame: NSRect, mono: Bool = false, tracking: CGFloat = 0) -> NSTextField {
    let t = NSTextField(labelWithString: text)
    t.frame = frame
    t.drawsBackground = false
    t.isBezeled = false
    t.isEditable = false
    t.isSelectable = false
    t.lineBreakMode = .byTruncatingTail
    t.maximumNumberOfLines = 1
    let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight)
    let ps = NSMutableParagraphStyle(); ps.alignment = .center
    t.attributedStringValue = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: color, .kern: tracking, .paragraphStyle: ps
    ])
    return t
}

/// Ekran ölçüsüne göre yerleşim bilgisi
struct Canvas {
    let view: NSView, w: CGFloat, h: CGFloat, s: CGFloat
    var cy: CGFloat { h / 2 }
    func row(_ y: CGFloat, _ height: CGFloat) -> NSRect { NSRect(x: 0, y: y, width: w, height: height) }
}

// MARK: - Akış: soru → seans → özet

final class Controller {
    enum Phase { case prompt, confirm, workout, summary, notice }

    var phase = Phase.prompt
    var roots: [NSView] = []
    var windows: [KeyWindow] = []
    var contents: [NSView] = []
    var clocks: [NSTextField] = []
    var fills: [NSView] = []
    var barW: [CGFloat] = []
    var confirmHints: [NSTextField] = []
    var passButtons: [ActionButton] = []
    var timer: Timer?
    var deadline: Timer?
    /// Küçültülmüş seansta köşede duran küçük sayaç (müzik açmak vb. için bilgisayar kullanılabilir)
    var mini: NSPanel?
    var miniClock: NSTextField?
    var start = Date()
    let triggeredAt = Date()

    // MARK: Pencereler

    func setup() {
        for (i, screen) in NSScreen.screens.enumerated() {
            let f = screen.frame
            let win = KeyWindow(contentRect: f, styleMask: .borderless, backing: .buffered, defer: false)
            win.level = .screenSaver
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            win.isOpaque = true
            win.hasShadow = false
            win.backgroundColor = C_BG2
            win.isReleasedWhenClosed = false
            // Ekran yakalama/paylaşımında bu pencere gösterilmesin (destekleyen yakalayıcılarda)
            win.sharingType = .none

            let root = NSView(frame: NSRect(origin: .zero, size: f.size))
            root.wantsLayer = true
            let grad = CAGradientLayer()
            grad.frame = root.bounds
            grad.colors = [C_BG1.cgColor, C_BG2.cgColor]
            grad.startPoint = CGPoint(x: 0.5, y: 1)
            grad.endPoint = CGPoint(x: 0.5, y: 0)
            root.layer?.addSublayer(grad)
            win.contentView = root

            if i == 0 { win.makeKeyAndOrderFront(nil) } else { win.orderFrontRegardless() }
            windows.append(win); roots.append(root)
        }

        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
            guard let self = self else { return ev }
            // Onay ekranında yazı kutusu tuşları alabilsin; yalnızca Esc'i yakala
            if self.phase == .confirm && ev.keyCode != 53 { return ev }
            self.key(ev.keyCode); return nil
        }
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] ev in
            if self?.phase == .summary { self?.quit() }
            return ev
        }
        if let n = notice { showNotice(n) } else { showPrompt() }
    }

    /// Her ekranın içeriğini yeniden kurar
    func render(_ build: (Canvas, Int) -> Void) {
        contents.forEach { $0.removeFromSuperview() }
        contents = []; clocks = []; fills = []; barW = []; confirmHints = []; passButtons = []
        for (i, root) in roots.enumerated() {
            let c = NSView(frame: root.bounds)
            c.alphaValue = 0
            root.addSubview(c)
            let s = max(0.62, min(1.05, root.bounds.width / 1512.0))
            build(Canvas(view: c, w: root.bounds.width, h: root.bounds.height, s: s), i)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                c.animator().alphaValue = 1
            }
            contents.append(c)
        }
    }

    func key(_ code: UInt16) {
        let enter = code == 36 || code == 76, esc = code == 53
        switch phase {
        case .prompt:  if enter { startWorkout() } else if esc { askToSkip() }
        case .confirm: if esc { showPrompt(first: false) }
        case .workout: if esc { finishWorkout(early: true) } else if code == 46 { minimize() }  // M
        case .summary: quit()
        case .notice:  if enter { quit() }
        }
    }

    // MARK: 0) Gece uyarıları — yalnızca "Tamam" ile kapanır

    func showNotice(_ n: Notice) {
        phase = .notice
        let hour = Journal.timeFmt.string(from: triggeredAt)
        let title = n == .prepare ? "Uyku hazırlığı." : "Uyku vakti."
        let line = n == .prepare ? "Uyumak için hazırlıklarını yap." : "Bilgisayarı kapat, iyi geceler."
        let t = todayStats()
        let footer = "Bugün: \(t.sessions) seans · \(t.sportMin) dk spor · \(t.passes) pas"

        render { cv, _ in
            let s = cv.s, cy = cv.cy
            cv.view.addSubview(label("SAAT \(hour)", 14 * s, .semibold, C_NIGHT, cv.row(cy + 210 * s, 26 * s), tracking: 3))
            cv.view.addSubview(label(title, 104 * s, .bold, C_WHITE, cv.row(cy + 64 * s, 134 * s)))
            cv.view.addSubview(label(line, 28 * s, .medium, C_NIGHT, cv.row(cy + 8 * s, 42 * s)))
            cv.view.addSubview(label(footer, 19 * s, .regular, C_MUTED, cv.row(cy - 40 * s, 30 * s)))
            let bw = 220 * s, bh = 62 * s
            let ok = ActionButton("Tamam", primary: true,
                                  frame: NSRect(x: (cv.w - bw) / 2, y: cy - 150 * s, width: bw, height: bh),
                                  fontSize: 22 * s, color: C_NIGHT)
            ok.handler = { [weak self] in self?.quit() }
            cv.view.addSubview(ok)
            cv.view.addSubview(label("Enter  tamam", 13 * s, .regular, C_FAINT, cv.row(58, 22), tracking: 1.2))
        }
        NSSound(named: "Purr")?.play()
    }

    // MARK: 1) Soru

    func showPrompt(first: Bool = true) {
        phase = .prompt
        let today = DayStats(journal.today())
        let hour = Journal.timeFmt.string(from: triggeredAt)
        let tally: String
        if today.sessions + today.passes == 0 {
            tally = "Bugünün ilk seansı."
        } else {
            tally = "Bugün: \(today.sessions) seans · \(today.sportMin) dk spor · \(today.passes) pas"
        }

        render { cv, _ in
            let s = cv.s, cy = cv.cy
            cv.view.addSubview(label("SAAT \(hour)" + (isTrial ? "  ·  DENEME" : ""), 14 * s, .semibold, C_FAINT,
                                     cv.row(cy + 210 * s, 26 * s), tracking: 3))
            cv.view.addSubview(label("Spor vakti.", 112 * s, .bold, C_WHITE,
                                     cv.row(cy + 64 * s, 140 * s)))
            cv.view.addSubview(label(tally, 22 * s, .regular, C_MUTED,
                                     cv.row(cy + 14 * s, 34 * s)))

            let bw = 300 * s, bh = 66 * s, gap = 22 * s
            let x0 = (cv.w - (bw * 2 + gap)) / 2, by = cy - 110 * s
            let go = ActionButton("Başlıyorum · \(isTrial ? "20 sn" : "\(SESSION_MIN) dk")", primary: true,
                                  frame: NSRect(x: x0, y: by, width: bw, height: bh), fontSize: 22 * s)
            go.handler = { [weak self] in self?.startWorkout() }
            let pass = ActionButton("Pas geçiyorum", primary: false,
                                    frame: NSRect(x: x0 + bw + gap, y: by, width: bw, height: bh), fontSize: 22 * s)
            pass.handler = { [weak self] in self?.askToSkip() }
            cv.view.addSubview(go); cv.view.addSubview(pass)

            cv.view.addSubview(label("Enter  başla        Esc  pas geç", 13 * s, .regular, C_FAINT,
                                     cv.row(58, 22), tracking: 1.2))
        }
        guard first else { return }
        NSSound(named: "Hero")?.play()

        deadline = Timer.scheduledTimer(withTimeInterval: ANSWER_TIMEOUT, repeats: false) { [weak self] _ in
            guard let self = self, self.phase == .prompt || self.phase == .confirm else { return }
            journal.append(.noAnswer, planned: SESSION_MIN, done: 0, at: self.triggeredAt)
            self.quit()
        }
    }

    // MARK: 1b) Pas onayı — "evet" yazılmadan pas geçilmez

    func askToSkip() {
        guard phase == .prompt else { return }
        phase = .confirm
        let t = todayStats()
        let n = t.passes + 1
        let missed = t.missedMin + SESSION_MIN
        var field: EntryField?

        render { cv, i in
            let s = cv.s, cy = cv.cy
            cv.view.addSubview(label("EMİN MİSİN?", 14 * s, .semibold, C_WARN, cv.row(cy + 230 * s, 26 * s), tracking: 3))
            cv.view.addSubview(label("Bugün \(n). pas olacak.", 84 * s, .bold, C_WHITE, cv.row(cy + 104 * s, 110 * s)))
            cv.view.addSubview(label("Bugün toplam \(missed) dakika spordan mahrum kalacaksın.", 28 * s, .medium, C_WARN,
                                     cv.row(cy + 50 * s, 42 * s)))
            let hint = label("Pas geçmek için  evet  yaz, sonra  Pas geç  düğmesine bas.", 19 * s, .regular, C_MUTED,
                             cv.row(cy - 2 * s, 30 * s))
            cv.view.addSubview(hint)
            self.confirmHints.append(hint)

            let fw = 280 * s, fh = 60 * s
            let box = NSView(frame: NSRect(x: (cv.w - fw) / 2, y: cy - 90 * s, width: fw, height: fh))
            box.wantsLayer = true
            box.layer?.cornerRadius = fh / 2
            box.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
            box.layer?.borderWidth = 1
            box.layer?.borderColor = C_WARN.withAlphaComponent(0.55).cgColor
            cv.view.addSubview(box)
            if i == 0 {
                let fs = 26 * s
                let f = EntryField(frame: NSRect(x: 20, y: (fh - fs * 1.3) / 2, width: fw - 40, height: fs * 1.3), fontSize: fs)
                f.handler = { [weak self] text in self?.typedEnter(text) }
                f.onChange = { [weak self] text in
                    self?.passButtons.forEach { $0.setActive(isYes(text)) }
                }
                box.addSubview(f)
                field = f
            }

            // İki net seçenek: hangisine basıldıysa o kaydedilir
            let bw = 260 * s, bh = 60 * s, gap = 22 * s
            let x0 = (cv.w - (bw * 2 + gap)) / 2, by = cy - 190 * s
            let pass = ActionButton("Pas geç", primary: true,
                                    frame: NSRect(x: x0, y: by, width: bw, height: bh),
                                    fontSize: 21 * s, color: C_WARN)
            pass.handler = { [weak self] in self?.confirmSkip() }
            pass.setActive(false)
            self.passButtons.append(pass)
            let go = ActionButton("Spora başla", primary: true,
                                  frame: NSRect(x: x0 + bw + gap, y: by, width: bw, height: bh), fontSize: 21 * s)
            go.handler = { [weak self] in self?.startWorkout() }
            cv.view.addSubview(pass); cv.view.addSubview(go)

            cv.view.addSubview(label("Esc  geri dön", 13 * s, .regular, C_FAINT, cv.row(58, 22), tracking: 1.2))
        }
        if let f = field { windows.first?.makeFirstResponder(f) }
    }

    /// "Pas geç" yalnızca kutuya "evet" yazıldıktan sonra etkinleşir.
    func confirmSkip() {
        guard phase == .confirm, passButtons.first?.isEnabled == true else { return }
        deadline?.invalidate()
        journal.append(.skipped, planned: SESSION_MIN, done: 0, at: triggeredAt)
        quit()
    }

    /// Kutuda Enter: karar düğmelerle verilir, burada yalnızca yol gösterilir.
    func typedEnter(_ text: String) {
        guard phase == .confirm else { return }
        let message: String
        if isYes(text) {
            message = "Şimdi seç:  Pas geç  ya da  Spora başla."
        } else {
            NSSound(named: "Funk")?.play()
            message = "Sadece  evet  yazarsan pas geçebilirsin."
            (windows.first?.firstResponder as? NSTextView)?.string = ""
            passButtons.forEach { $0.setActive(false) }
        }
        for h in confirmHints {
            let attrs = h.attributedStringValue.attributes(at: 0, effectiveRange: nil)
            h.attributedStringValue = NSAttributedString(string: message, attributes: attrs)
        }
    }

    // MARK: 2) Seans

    func startWorkout() {
        guard phase == .prompt || phase == .confirm else { return }
        deadline?.invalidate()
        phase = .workout
        render { cv, _ in
            let s = cv.s, cy = cv.cy
            cv.view.addSubview(label(isTrial ? "SPOR  ·  DENEME" : "SPOR  ·  \(SESSION_MIN) DAKİKA", 14 * s, .semibold,
                                     C_FAINT, cv.row(cy + 190 * s, 26 * s), tracking: 3))
            let clock = label("00:00", 150 * s, .medium, C_ACCENT, cv.row(cy - 10 * s, 180 * s), mono: true)
            cv.view.addSubview(clock)

            let bw = min(620, cv.w * 0.45)
            let track = NSView(frame: NSRect(x: (cv.w - bw) / 2, y: cy - 40 * s, width: bw, height: 6))
            track.wantsLayer = true
            track.layer?.backgroundColor = NSColor(white: 1, alpha: 0.09).cgColor
            track.layer?.cornerRadius = 3
            let fill = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 6))
            fill.wantsLayer = true
            fill.layer?.backgroundColor = C_ACCENT.cgColor
            fill.layer?.cornerRadius = 3
            track.addSubview(fill)
            cv.view.addSubview(track)

            cv.view.addSubview(label("Bilgisayar seni bekler.", 22 * s, .regular, C_MUTED,
                                     cv.row(cy - 100 * s, 34 * s)))

            let ew = 240 * s, eh = 52 * s, gap = 18 * s
            let x0 = (cv.w - (ew * 2 + gap)) / 2
            let shrink = ActionButton("Küçült · müzik aç", primary: false,
                                      frame: NSRect(x: x0, y: cy - 190 * s, width: ew, height: eh),
                                      fontSize: 17 * s)
            shrink.handler = { [weak self] in self?.minimize() }
            let early = ActionButton("Erken bitir", primary: false,
                                     frame: NSRect(x: x0 + ew + gap, y: cy - 190 * s, width: ew, height: eh),
                                     fontSize: 17 * s)
            early.handler = { [weak self] in self?.finishWorkout(early: true) }
            cv.view.addSubview(shrink); cv.view.addSubview(early)

            cv.view.addSubview(label("M  küçült        Esc  erken bitir", 13 * s, .regular, C_FAINT,
                                     cv.row(58, 22), tracking: 1.2))
            self.clocks.append(clock); self.fills.append(fill); self.barW.append(bw)
        }

        start = Date()
        tick()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func tick() {
        let elapsed = Date().timeIntervalSince(start)
        let remain = SESSION_SEC - elapsed
        if remain <= 0 { finishWorkout(early: false); return }
        let sec = Int(ceil(remain))
        let text = String(format: "%02d:%02d", sec / 60, sec % 60)
        for c in clocks where c.stringValue != text {
            // Biçimi (font, renk, ortalama) koruyarak yalnızca metni değiştir
            let attrs = c.attributedStringValue.attributes(at: 0, effectiveRange: nil)
            c.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
        }
        let ratio = CGFloat(min(1, elapsed / SESSION_SEC))
        for (i, f) in fills.enumerated() { f.frame.size.width = barW[i] * ratio }
        if let c = miniClock, c.stringValue != text {
            let attrs = c.attributedStringValue.attributes(at: 0, effectiveRange: nil)
            c.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
        }
    }

    // MARK: 2b) Küçültülmüş seans — sayaç sürer, bilgisayar kullanılabilir

    func minimize() {
        guard phase == .workout, mini == nil else { return }
        let w: CGFloat = 250, h: CGFloat = 112, m: CGFloat = 20
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let panel = NSPanel(contentRect: NSRect(x: vf.maxX - w - m, y: vf.maxY - h - m, width: w, height: h),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.sharingType = .none

        let root = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        root.wantsLayer = true
        root.layer?.cornerRadius = 18
        root.layer?.backgroundColor = C_BG2.withAlphaComponent(0.94).cgColor
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        panel.contentView = root

        root.addSubview(label("SPOR", 10, .semibold, C_FAINT, NSRect(x: 0, y: h - 26, width: w, height: 16), tracking: 2.5))
        let clock = label("00:00", 34, .medium, C_ACCENT, NSRect(x: 0, y: 44, width: w, height: 42), mono: true)
        root.addSubview(clock)
        let bw: CGFloat = 105, bh: CGFloat = 28, gap: CGFloat = 10
        let x0 = (w - (bw * 2 + gap)) / 2
        let big = ActionButton("Büyüt", primary: false, frame: NSRect(x: x0, y: 12, width: bw, height: bh), fontSize: 13)
        big.handler = { [weak self] in self?.expand() }
        let end = ActionButton("Erken bitir", primary: false,
                               frame: NSRect(x: x0 + bw + gap, y: 12, width: bw, height: bh), fontSize: 13)
        end.handler = { [weak self] in self?.finishWorkout(early: true) }
        root.addSubview(big); root.addSubview(end)

        mini = panel; miniClock = clock
        tick()
        windows.forEach { $0.orderOut(nil) }
        panel.orderFrontRegardless()
        NSApp.deactivate()
    }

    /// Tam ekrana geri döner (Büyüt, ya da seans bitince özet için)
    func expand() {
        guard let panel = mini else { return }
        panel.orderOut(nil)
        mini = nil; miniClock = nil
        for (i, win) in windows.enumerated() {
            if i == 0 { win.makeKeyAndOrderFront(nil) } else { win.orderFrontRegardless() }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func finishWorkout(early: Bool) {
        guard phase == .workout else { return }
        timer?.invalidate()
        expand()
        let elapsed = Date().timeIntervalSince(start)
        let doneMin = early ? min(SESSION_MIN, Int(elapsed / 60)) : SESSION_MIN

        if !early || doneMin >= SESSION_MIN {
            journal.append(.done, planned: SESSION_MIN, done: SESSION_MIN, at: triggeredAt)
            NSSound(named: "Glass")?.play()
            showDone()
        } else if doneMin == 0 {
            journal.append(.skipped, planned: SESSION_MIN, done: 0, at: triggeredAt)
            showPassSummary()
        } else {
            journal.append(.partial, planned: SESSION_MIN, done: doneMin, at: triggeredAt)
            showPartial(doneMin)
        }
    }

    // MARK: 3) Özet

    func summary(kicker: String, kickerColor: NSColor, title: String,
                 line: String, lineColor: NSColor, footer: String) {
        phase = .summary
        render { cv, _ in
            let s = cv.s, cy = cv.cy
            cv.view.addSubview(label(kicker, 14 * s, .semibold, kickerColor, cv.row(cy + 190 * s, 26 * s), tracking: 3))
            cv.view.addSubview(label(title, 96 * s, .bold, C_WHITE, cv.row(cy + 50 * s, 124 * s)))
            cv.view.addSubview(label(line, 30 * s, .medium, lineColor, cv.row(cy - 10 * s, 44 * s)))
            cv.view.addSubview(label(footer, 20 * s, .regular, C_MUTED, cv.row(cy - 70 * s, 32 * s)))
            cv.view.addSubview(label("Kapatmak için bir tuşa bas ya da tıkla", 13 * s, .regular, C_FAINT,
                                     cv.row(58, 22), tracking: 1.2))
        }
        Timer.scheduledTimer(withTimeInterval: SUMMARY_SEC, repeats: false) { [weak self] _ in self?.quit() }
    }

    func todayStats() -> DayStats {
        // Deneme modunda kayıt yazılmadığından bugünkü tabloya bu seans eklenmez.
        DayStats(journal.today())
    }

    func showPassSummary() {
        let t = todayStats()
        let n = max(1, t.passes)
        summary(kicker: "PAS GEÇİLDİ", kickerColor: C_WARN,
                title: "Bugün \(n). pas.",
                line: "Bugün toplam \(max(t.missedMin, SESSION_MIN)) dakika spordan mahrum kaldın.",
                lineColor: C_WARN,
                footer: "Bugün yapılan: \(t.sessions) seans · \(t.sportMin) dk spor")
    }

    func showPartial(_ doneMin: Int) {
        let t = todayStats()
        summary(kicker: "ERKEN BİTTİ", kickerColor: C_WARN,
                title: "\(doneMin) dk spor.",
                line: "Bugün toplam \(t.missedMin) dakika spordan mahrum kaldın.",
                lineColor: C_WARN,
                footer: "Bugün: \(t.sessions) seans · \(t.sportMin) dk spor · \(t.passes) pas")
    }

    func showDone() {
        let t = todayStats()
        let n = max(1, t.sessions)
        let missed = t.missedMin > 0 ? " · \(t.missedMin) dk kaçırıldı" : ""
        summary(kicker: "TAMAMLANDI", kickerColor: C_ACCENT,
                title: "Bugün \(n). seans.",
                line: "Bugün toplam \(max(t.sportMin, SESSION_MIN)) dakika spor yaptın.",
                lineColor: C_ACCENT,
                footer: "\(t.passes) pas\(missed)")
    }

    func quit() {
        timer?.invalidate()
        windows.forEach { $0.orderOut(nil) }
        exit(0)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
controller.setup()
app.activate(ignoringOtherApps: true)
app.run()
