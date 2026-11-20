// Draws the Pastry app icon (clipboard + glazed donut on a warm rounded square) and writes an .iconset folder.
// Usage: make-icon <out.iconset>
import AppKit

func color(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r) }

// Everything is drawn on a 1024 grid and scaled.
func draw() {
    // background squircle with soft shadow
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.3); sh.shadowBlurRadius = 24; sh.shadowOffset = NSSize(width: 0, height: -12); sh.set()
    let bg = rr(100, 100, 824, 824, 186); color(0xF2994A).setFill(); bg.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0xFFCB77), ending: color(0xEE7F38))?.draw(in: bg, angle: -90)
    // clipboard board
    NSGraphicsContext.saveGraphicsState()
    let s2 = NSShadow(); s2.shadowColor = .black.withAlphaComponent(0.25); s2.shadowBlurRadius = 14; s2.shadowOffset = NSSize(width: 0, height: -6); s2.set()
    color(0x8A5230).setFill(); rr(268, 170, 470, 620, 48).fill()
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFF7EA).setFill(); rr(296, 196, 414, 560, 30).fill()
    for i in 0..<4 { color(0xE0C9A8).setFill(); rr(344, 650 - CGFloat(i) * 78, i == 3 ? 150 : 318, 26, 13).fill() }
    // clip
    color(0xB8B2AA).setFill(); rr(398, 724, 210, 110, 30).fill()
    color(0x8E8880).setFill(); rr(432, 760, 142, 38, 19).fill()
    // donut
    let c = NSPoint(x: 690, y: 330)
    NSGraphicsContext.saveGraphicsState()
    let s3 = NSShadow(); s3.shadowColor = .black.withAlphaComponent(0.3); s3.shadowBlurRadius = 12; s3.shadowOffset = NSSize(width: 0, height: -6); s3.set()
    func ring(_ r: CGFloat, _ hole: CGFloat, _ col: NSColor) {
        let p = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        p.append(NSBezierPath(ovalIn: NSRect(x: c.x - hole, y: c.y - hole, width: 2 * hole, height: 2 * hole))); p.windingRule = .evenOdd; col.setFill(); p.fill()
    }
    ring(150, 48, color(0xD9944A)); NSGraphicsContext.restoreGraphicsState()
    ring(132, 56, color(0xF57BA6))
    for (i, a) in [20.0, 75, 130, 190, 245, 305].enumerated() {
        let rad = (a + 12) * .pi / 180, d: CGFloat = 96
        let t = NSAffineTransform(); t.translateX(by: c.x + cos(rad) * d, yBy: c.y + sin(rad) * d); t.rotate(byDegrees: CGFloat(a * 3).truncatingRemainder(dividingBy: 180)); 
        let p = rr(-18, -6, 36, 12, 6); p.transform(using: t as AffineTransform)
        [color(0xFFFFFF), color(0xFFF2A8), color(0x9DE0FF)][i % 3].setFill(); p.fill()
    }
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let t = NSAffineTransform(); t.scale(by: CGFloat(px) / 1024); t.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
