// Uygulama ikonunu üretir: koyu yuvarlak kare üzerinde yeşil koşan adam (SF Symbol "figure.run").
// Kullanım: swift scripts/ikon.swift assets/SporVakti.icns
import AppKit
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/SporVakti.icns"
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("SporVakti.iconset")
try? FileManager.default.removeItem(at: tmp)
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let S = CGFloat(px)
    // macOS ikon ızgarası: 1024'te 824'lük kare, köşe yarıçapı ~185
    let inset = S * 100 / 1024, side = S - inset * 2
    let rect = NSRect(x: inset, y: inset, width: side, height: side)
    let path = NSBezierPath(roundedRect: rect, xRadius: side * 0.225, yRadius: side * 0.225)
    NSGradient(starting: NSColor(srgbRed: 0.09, green: 0.14, blue: 0.18, alpha: 1),
               ending: NSColor(srgbRed: 0.02, green: 0.03, blue: 0.045, alpha: 1))!.draw(in: path, angle: -90)
    let cfg = NSImage.SymbolConfiguration(pointSize: side * 0.52, weight: .bold)
        .applying(.init(paletteColors: [NSColor(srgbRed: 0.36, green: 0.82, blue: 0.66, alpha: 1)]))
    if let sym = NSImage(systemSymbolName: "figure.run", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = sym.size
        sym.draw(in: NSRect(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2, width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: tmp.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: tmp.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", tmp.path, "-o", out]
try! p.run(); p.waitUntilExit()
try? FileManager.default.copyItem(at: tmp.appendingPathComponent("icon_512x512@2x.png"),
                                  to: URL(fileURLWithPath: out).deletingPathExtension().appendingPathExtension("png"))
print(p.terminationStatus == 0 ? "✅ \(out)" : "❌ iconutil")
