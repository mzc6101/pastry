// Pastry: card rendering (header tint, thumbnails, relative time).
import AppKit

enum Visual {
    static var iconCache: [String: NSImage] = [:], tintCache: [String: NSColor] = [:], thumbCache: [Int64: NSImage] = [:]
    static func icon(_ bundle: String) -> NSImage? {
        if let i = iconCache[bundle] { return i }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return nil }
        let i = NSWorkspace.shared.icon(forFile: url.path); iconCache[bundle] = i; return i
    }
    // dominant colour: saturation-weighted average of a 16x16 downsample of the icon
    static func tint(_ bundle: String, kind: String) -> NSColor {
        if let c = tintCache[bundle] { return c }
        var out = [NSColor.systemBlue, .systemTeal, .systemPurple, .systemOrange][["text": 0, "link": 1, "image": 2, "file": 3][kind] ?? 0]
        if let img = icon(bundle), let ctx = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil), let px = ctx.data?.bindMemory(to: UInt8.self, capacity: 1024) {
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 16, height: 16))
            var r = 0.0, g = 0.0, b = 0.0, w = 0.0
            for i in 0..<256 where px[i * 4 + 3] > 200 {
                let c = NSColor(red: CGFloat(px[i*4]) / 255, green: CGFloat(px[i*4+1]) / 255, blue: CGFloat(px[i*4+2]) / 255, alpha: 1)
                let wt = Double(c.saturationComponent * c.brightnessComponent) + 0.02
                r += wt * Double(c.redComponent); g += wt * Double(c.greenComponent); b += wt * Double(c.blueComponent); w += wt
            }
            if w > 0 { let c = NSColor(red: r / w, green: g / w, blue: b / w, alpha: 1)
                out = NSColor(hue: c.hueComponent, saturation: min(1, c.saturationComponent * 1.1), brightness: min(0.82, max(0.5, c.brightnessComponent)), alpha: 1) }
        }
        tintCache[bundle] = out; return out
    }
    /// The app whose icon heads a card: where the item was copied from; if that is unknown / Pastry itself / not installed, a default for the content.
    /// Resolved once per row and cached (icons and tints are cached per bundle id), so drawing never repeats lookups.
    static var sourceCache: [Int64: String] = [:]
    static func source(_ r: Store.Row) -> String {
        if let c = sourceCache[r.id] { return c }
        let me = Bundle.main.bundleIdentifier ?? "com.manavchordia.pastry"
        func installed(_ id: String) -> Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil }
        func first(_ ids: [String]) -> String? { ids.first(where: installed) }
        func bundle(of url: URL?) -> String? { url.flatMap { Bundle(url: $0)?.bundleIdentifier } }
        var out = r.bundle
        if out.isEmpty || out == me || !installed(out) {
            let ext = (r.title as NSString).pathExtension.lowercased()
            switch r.kind {
            case "image": out = first(["com.apple.Photos", "com.apple.Preview"]) ?? ""
            case "link": out = bundle(of: NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com")!)) ?? "com.apple.Safari"
            case "file":
                let named: [String: [String]] = ["pptx": ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint"], "ppt": ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint"], "key": ["com.apple.iWork.Keynote"],
                    "doc": ["com.apple.iWork.Pages", "com.microsoft.Word"], "docx": ["com.apple.iWork.Pages", "com.microsoft.Word"], "pages": ["com.apple.iWork.Pages"],
                    "xls": ["com.apple.iWork.Numbers", "com.microsoft.Excel"], "xlsx": ["com.apple.iWork.Numbers", "com.microsoft.Excel"], "numbers": ["com.apple.iWork.Numbers"], "csv": ["com.apple.iWork.Numbers"], "pdf": ["com.apple.Preview"]]
                out = first(named[ext] ?? []) ?? bundle(of: ext.isEmpty ? nil : NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/x." + ext))) ?? "com.apple.finder"
            default: out = "com.apple.TextEdit" }
        }
        sourceCache[r.id] = out; return out
    }
    static func thumb(_ id: Int64, store: Store) -> NSImage? {
        if let t = thumbCache[id] { return t }
        guard let d = store.flavors(id).first(where: { $0.0 == NSPasteboard.PasteboardType.png.rawValue || $0.0 == thumbUTI })?.1,
              let src = CGImageSourceCreateWithData(d as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 600] as CFDictionary) else { return nil }
        let i = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)); thumbCache[id] = i; return i
    }
    /// Real picture for a copied image *file* (also rows stored before a thumbnail could be made); successes are cached.
    static func fileThumb(_ url: URL, key: Int64) -> NSImage? {
        if let t = thumbCache[key] { return t }
        guard Capture.isImage(url), let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let i = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)); thumbCache[key] = i; return i
    }
    static func ago(_ t: Double) -> String {
        let s = Int(Date().timeIntervalSince1970 - t)
        if s < 60 { return "Just now" }; if s < 3600 { return "\(s / 60) min ago" }; if s < 86400 { return "\(s / 3600) hr ago" }
        return Date(timeIntervalSince1970: t).formatted(date: .abbreviated, time: .omitted)
    }
}

final class CardView: NSView {
    static let size = NSSize(width: 232, height: 264), inset: CGFloat = 5, radius: CGFloat = 22
    let row: Store.Row; let store: Store; let index: Int
    var selected = false { didSet { needsDisplay = true } }
    var onClick: ((Int, Int) -> Void)?, onMenu: ((CardView) -> NSMenu?)?
    var suggested = false   // sparkle header, no ⌘N hint
    private var hovered = false, pressed = false
    private static let fill = dyn(NSColor.white.withAlphaComponent(0.74), NSColor.white.withAlphaComponent(0.10))
    private static let footer = dyn(NSColor.black.withAlphaComponent(0.04), NSColor.white.withAlphaComponent(0.06))
    private static let rim = dyn(NSColor.black.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0.20))
    init(row: Store.Row, index: Int, store: Store) {
        self.row = row; self.store = store; self.index = index
        super.init(frame: NSRect(origin: .zero, size: CardView.size)); wantsLayer = true
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func mouseDown(with e: NSEvent) { pressed = true; spring(); onClick?(index, e.clickCount) }
    override func menu(for e: NSEvent) -> NSMenu? { onMenu?(self) }   // right-click / ctrl-click
    override func mouseUp(with e: NSEvent) { pressed = false; spring() }
    override func mouseEntered(with e: NSEvent) { hovered = true; spring() }
    override func mouseExited(with e: NSEvent) { hovered = false; pressed = false; spring() }
    // springy hover / press: scale about the centre whatever the layer's anchor point is
    private func spring() {
        guard let l = layer else { return }
        let s: CGFloat = pressed ? 0.97 : hovered ? 1.025 : 1, c = CGPoint(x: bounds.midX, y: bounds.midY)
        let a = CGPoint(x: l.anchorPoint.x * bounds.width, y: l.anchorPoint.y * bounds.height)
        let t = CATransform3DTranslate(CATransform3DMakeScale(s, s, 1), (c.x - a.x) * (1 - s), (c.y - a.y) * (1 - s), 0)
        let anim = CASpringAnimation(keyPath: "transform"); anim.fromValue = l.presentation()?.transform ?? l.transform; anim.toValue = t
        anim.damping = 13; anim.stiffness = 320; anim.mass = 1; anim.duration = anim.settlingDuration
        l.transform = t; l.add(anim, forKey: "spring")
    }

    /// Tile entrance / exit: fade + 0.96 scale + slight x offset on a spring (plain fade when Reduce Motion is on).
    func animate(appear: Bool, delay: Double, reduce: Bool) {
        guard let l = layer else { return }
        let begin = CACurrentMediaTime() + delay, c = CGPoint(x: bounds.midX, y: bounds.midY), a = CGPoint(x: l.anchorPoint.x * bounds.width, y: l.anchorPoint.y * bounds.height)
        let away = CATransform3DTranslate(CATransform3DMakeScale(0.96, 0.96, 1), (c.x - a.x) * 0.04 + 36, (c.y - a.y) * 0.04, 0), home = CATransform3DIdentity
        let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = appear ? 0 : 1; fade.toValue = appear ? 1 : 0; fade.duration = 0.25; fade.beginTime = begin; fade.fillMode = .both
        l.opacity = appear ? 1 : 0; l.add(fade, forKey: "fade")
        guard !reduce else { return }
        let sp = CASpringAnimation(keyPath: "transform"); sp.fromValue = appear ? away : home; sp.toValue = appear ? home : away
        sp.damping = 15; sp.stiffness = 240; sp.mass = 1; sp.duration = sp.settlingDuration; sp.beginTime = begin; sp.fillMode = .both
        l.transform = appear ? home : away; l.add(sp, forKey: "enter")
    }
    func text(_ s: String, _ r: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor, mono: Bool = false, align: NSTextAlignment = .left) {
        let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byWordWrapping
        let f = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        NSString(string: s).draw(with: r, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: [.font: f, .foregroundColor: color, .paragraphStyle: p])
    }
    func symbol(_ name: String, in r: NSRect, size: CGFloat, color: NSColor) {
        guard let img = Glass.symbol(name, size: size, weight: .semibold, color: color) else { return }
        img.draw(in: NSRect(x: r.midX - img.size.width / 2, y: r.midY - img.size.height / 2, width: img.size.width, height: img.size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    private func cover(_ t: NSImage, in body: NSRect) {
        let sc = max(body.width / t.size.width, body.height / t.size.height), sz = NSSize(width: t.size.width * sc, height: t.size.height * sc)
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect: body).addClip()
        t.draw(in: NSRect(x: body.midX - sz.width / 2, y: body.midY - sz.height / 2, width: sz.width, height: sz.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
    }
    override func draw(_ dirty: NSRect) {
        let card = bounds.insetBy(dx: CardView.inset, dy: CardView.inset), R = CardView.radius
        let shape = NSBezierPath(roundedRect: card, xRadius: R, yRadius: R)
        CardView.fill.setFill(); shape.fill()
        NSGraphicsContext.saveGraphicsState(); shape.addClip()
        // header: soft tint gradient, kind symbol + label + time, app icon
        let hh: CGFloat = 56, src = Visual.source(row), tint = Visual.tint(src, kind: row.kind)
        let head = NSRect(x: card.minX, y: card.minY, width: card.width, height: hh)
        NSGradient(starting: (tint.blended(withFraction: 0.18, of: .white) ?? tint).withAlphaComponent(0.95), ending: (tint.blended(withFraction: 0.1, of: .black) ?? tint).withAlphaComponent(0.95))?.draw(in: head, angle: 90)
        let label = ["text": "Text", "link": "Link", "image": "Image", "file": "File"][row.kind] ?? "Item"
        let kindSym = suggested ? "sparkles" : ["text": "text.alignleft", "link": "link", "image": "photo", "file": "doc.fill"][row.kind] ?? "square"
        symbol(kindSym, in: NSRect(x: card.minX + 14, y: card.minY + 12, width: 16, height: 18), size: 12, color: NSColor.white.withAlphaComponent(0.95))
        text(label, NSRect(x: card.minX + 34, y: card.minY + 11, width: card.width - 90, height: 18), size: 14, weight: .semibold, color: .white)
        text(Visual.ago(row.created), NSRect(x: card.minX + 14, y: card.minY + 33, width: card.width - 70, height: 14), size: 11, weight: .medium, color: NSColor.white.withAlphaComponent(0.82))
        if let ic = Visual.icon(src) { ic.draw(in: NSRect(x: card.maxX - 50, y: card.minY + 8, width: 40, height: 40), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil) }
        // body
        let body = NSRect(x: card.minX, y: card.minY + hh, width: card.width, height: card.height - hh - 30)
        let pad = body.insetBy(dx: 14, dy: 12)
        switch row.kind {
        case "image": if let t = Visual.thumb(row.id, store: store) { cover(t, in: body) }
        case "file":
            let url = store.flavors(row.id).first.flatMap { String(decoding: $0.1, as: UTF8.self).split(separator: "\n").first }.flatMap { URL(string: String($0)) }
            if let u = url, let t = Visual.fileThumb(u, key: row.id) { cover(t, in: body); break }
            let ic = NSWorkspace.shared.icon(forFile: url?.path ?? "/")
            ic.draw(in: NSRect(x: body.midX - 36, y: body.minY + 28, width: 72, height: 72), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            text(row.title, NSRect(x: pad.minX, y: body.minY + 112, width: pad.width, height: 60), size: 12, weight: .medium, color: .labelColor, align: .center)
        case "link":
            text(row.preview.isEmpty ? row.title : row.preview, pad, size: 13, weight: .medium, color: dyn(.systemBlue, NSColor(red: 0.45, green: 0.72, blue: 1, alpha: 1)))
        default:
            text(row.preview.isEmpty ? row.title : row.preview, pad, size: 12, color: .labelColor)
        }
        // footer
        CardView.footer.setFill(); NSRect(x: card.minX, y: card.maxY - 30, width: card.width, height: 30).fill()
        text(row.meta.isEmpty ? label : row.meta, NSRect(x: card.minX + 30, y: card.maxY - 22, width: card.width - 60, height: 14), size: 11, color: .secondaryLabelColor, align: .center)
        if index < 9, !suggested { text("⌘\(index + 1)", NSRect(x: card.maxX - 40, y: card.maxY - 21, width: 30, height: 14), size: 10, weight: .medium, color: .tertiaryLabelColor, align: .right) }
        if row.pin != nil { symbol("pin.fill", in: NSRect(x: card.minX + 8, y: card.maxY - 26, width: 20, height: 22), size: 11, color: .systemOrange) }
        NSGraphicsContext.restoreGraphicsState()
        CardView.rim.setStroke(); shape.lineWidth = 0.5; shape.stroke()
        if selected {   // concentric ring: 2.5pt gap outside the card, radius grows by the gap
            let ring = NSBezierPath(roundedRect: card.insetBy(dx: -3.5, dy: -3.5), xRadius: R + 3.5, yRadius: R + 3.5)
            NSColor.controlAccentColor.setStroke(); ring.lineWidth = 3; ring.stroke()
        }
    }
}
