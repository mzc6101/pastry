// Pastry: shared look. Liquid Glass (macOS 26+) with a material fallback, glass buttons, the sliding pill segmented control,
// and the Accessibility banner + live trust monitor.
import AppKit
import ApplicationServices

func dyn(_ light: NSColor, _ dark: NSColor) -> NSColor {
    NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light }
}

/// A flat rounded tile (fill + hairline border + optional soft shadow) that follows light/dark appearance.
final class Tile: NSView {
    var radius: CGFloat { didSet { needsDisplay = true } }
    var fill: NSColor, border: NSColor, lifted: Bool
    init(radius: CGFloat, fill: NSColor, border: NSColor = .clear, lifted: Bool = false) {
        self.radius = radius; self.fill = fill; self.border = border; self.lifted = lifted
        super.init(frame: .zero); wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        guard let l = layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            l.backgroundColor = fill.cgColor; l.borderColor = border.cgColor; l.borderWidth = border == .clear ? 0 : 0.5
            l.cornerRadius = radius; l.cornerCurve = .continuous
            l.shadowOpacity = lifted ? 0.22 : 0; l.shadowRadius = 4; l.shadowOffset = CGSize(width: 0, height: -1.5); l.shadowColor = NSColor.black.cgColor
        }
    }
}

enum Glass {
    static let native: Bool = { if #available(macOS 26, *) { return ProcessInfo.processInfo.environment["PASTRY_NO_GLASS"] == nil }; return false }()

    /// A glass surface (NSGlassEffectView on macOS 26+, a blurred material or flat translucent tile before that) with a plain content view pinned inside.
    static func surface(radius: CGFloat, tint: NSColor? = nil, material: NSVisualEffectView.Material? = nil) -> (view: NSView, content: NSView) {
        let content = NSView()
        if native, #available(macOS 26, *) {
            let g = NSGlassEffectView(); g.cornerRadius = radius; g.tintColor = tint; g.contentView = content; return (g, content)
        }
        let v: NSView
        if let m = material {
            let fx = NSVisualEffectView(); fx.material = m; fx.blendingMode = .behindWindow; fx.state = .active; fx.wantsLayer = true
            fx.layer?.cornerRadius = radius; fx.layer?.cornerCurve = .continuous; fx.layer?.masksToBounds = true
            fx.layer?.borderWidth = 0.5; fx.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor; v = fx
        } else { v = Tile(radius: radius, fill: dyn(NSColor.black.withAlphaComponent(0.06), NSColor.white.withAlphaComponent(0.12)), border: dyn(NSColor.black.withAlphaComponent(0.08), NSColor.white.withAlphaComponent(0.16))) }
        content.frame = v.bounds; content.autoresizingMask = [.width, .height]; v.addSubview(content); return (v, content)
    }

    /// Capsule glass push button (macOS 26 `.glass` bezel); rounded push button before that.
    static func button(_ title: String, symbol: String? = nil, prominent: Bool = false, target: AnyObject?, action: Selector?) -> NSButton {
        let b = NSButton(title: title, target: target, action: action); style(b, prominent: prominent)
        if let s = symbol { b.image = NSImage(systemSymbolName: s, accessibilityDescription: title); b.imagePosition = .imageLeading }
        return b
    }
    static func style(_ b: NSButton, prominent: Bool = false, circle: Bool = false) {
        if native, #available(macOS 26, *) { b.bezelStyle = .glass; b.borderShape = circle ? .circle : .capsule } else { b.bezelStyle = circle ? .circular : .rounded }
        if prominent { b.bezelColor = .controlAccentColor }
        b.font = .systemFont(ofSize: 12, weight: .medium)
    }
    static func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight = .medium, color: NSColor? = nil) -> NSImage? {
        var c = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        if let col = color { c = c.applying(NSImage.SymbolConfiguration(paletteColors: [col])) }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(c)
    }
}

/// Pill segmented control: a glass capsule with a selection capsule that slides between equal-width segments with a spring.
final class PillSegmented: NSView {
    let items: [(title: String, symbol: String)]
    var index = 0 { didSet { if index != oldValue { moveThumb(animated: true); labels.needsDisplay = true } } }
    var onChange: ((Int) -> Void)?
    private let thumb = Tile(radius: 14, fill: dyn(.white.withAlphaComponent(0.92), NSColor.white.withAlphaComponent(0.2)), border: dyn(NSColor.black.withAlphaComponent(0.06), NSColor.white.withAlphaComponent(0.2)), lifted: true)
    private let labels = LabelView()
    private final class LabelView: NSView {
        weak var owner: PillSegmented?
        override func draw(_ r: NSRect) {
            guard let o = owner else { return }
            let w = bounds.width / CGFloat(o.items.count)
            for (i, it) in o.items.enumerated() {
                let col: NSColor = i == o.index ? .labelColor : .secondaryLabelColor, seg = NSRect(x: CGFloat(i) * w, y: 0, width: w, height: bounds.height)
                let str = NSAttributedString(string: it.title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: col])
                let img = Glass.symbol(it.symbol, size: 12, weight: .semibold, color: col), iw = (img?.size.width ?? 0) + 6, total = iw + str.size().width
                var x = seg.midX - total / 2
                if let img { img.draw(at: NSPoint(x: x, y: seg.midY - img.size.height / 2), from: .zero, operation: .sourceOver, fraction: 1); x += iw }
                str.draw(at: NSPoint(x: x, y: seg.midY - str.size().height / 2))
            }
        }
        override func mouseDown(with e: NSEvent) {
            guard let o = owner else { return }
            let i = min(o.items.count - 1, max(0, Int(convert(e.locationInWindow, from: nil).x / (bounds.width / CGFloat(o.items.count)))))
            if i != o.index { o.index = i; o.onChange?(i) }
        }
    }
    let surface: NSView
    init(items: [(String, String)], frame: NSRect) {
        self.items = items.map { (title: $0.0, symbol: $0.1) }
        let (g, c) = Glass.surface(radius: frame.height / 2); surface = g
        super.init(frame: frame)
        g.frame = bounds; g.autoresizingMask = [.width, .height]; addSubview(g)
        c.addSubview(thumb); labels.owner = self; labels.frame = c.bounds; labels.autoresizingMask = [.width, .height]; c.addSubview(labels)
        moveThumb(animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() { super.layout(); moveThumb(animated: false) }
    private var thumbFrame: NSRect { let w = bounds.width / CGFloat(items.count); return NSRect(x: CGFloat(index) * w + 3, y: 3, width: w - 6, height: bounds.height - 6) }
    private func moveThumb(animated: Bool) {
        thumb.layer?.removeAnimation(forKey: "slide")
        let from = thumb.layer?.presentation()?.position
        thumb.frame = thumbFrame; thumb.radius = thumbFrame.height / 2
        guard animated, let from, let to = thumb.layer?.position else { return }
        let a = CASpringAnimation(keyPath: "position"); a.fromValue = NSValue(point: from); a.toValue = NSValue(point: to)
        a.damping = 16; a.stiffness = 320; a.mass = 1; a.duration = a.settlingDuration; thumb.layer?.add(a, forKey: "slide")
    }
}

// MARK: Accessibility trust

extension Notification.Name { static let axChanged = Notification.Name("PastryAXChanged") }

/// Tracks Accessibility trust live. A process started before the grant keeps AXIsProcessTrusted()==false until relaunch, so while
/// untrusted we ask a fresh copy of this binary (`--ax-check`) whether the grant exists now; yes means "granted, relaunch needed".
final class AXMonitor {
    enum State { case trusted, missing, stale }
    static let shared = AXMonitor()
    private(set) var state: State = AXIsProcessTrusted() ? .trusted : .missing
    private var timer: Timer?, holds = 0, checking = false
    func hold() { holds += 1; refresh(); if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() } } }
    func release() { holds = max(0, holds - 1); if holds == 0 { timer?.invalidate(); timer = nil } }
    func refresh() {
        if let f = ProcessInfo.processInfo.environment["PASTRY_AX_FORCE"] { set(f == "stale" ? .stale : f == "trusted" ? .trusted : .missing); return }   // debug: fake a state
        if AXIsProcessTrusted() { set(.trusted); return }
        guard !checking, let exe = Bundle.main.executableURL else { return }
        checking = true
        DispatchQueue.global().async {
            let p = Process(); p.executableURL = exe; p.arguments = ["--ax-check"]
            let ok = (try? p.run()) != nil && { p.waitUntilExit(); return p.terminationStatus == 0 }()
            DispatchQueue.main.async { self.checking = false; self.set(ok ? .stale : .missing) }
        }
    }
    private func set(_ s: State) {
        guard s != state else { return }
        state = s; log("accessibility state -> \(s)"); NotificationCenter.default.post(name: .axChanged, object: nil)
    }
    static func openSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
    static func relaunch() {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", "sleep 0.7; /usr/bin/open -n \"$0\" --args --relaunch", Bundle.main.bundlePath]
        try? p.run(); NSApp.terminate(nil)
    }
}

/// Glass capsule shown while Accessibility is missing (or granted but not yet effective). Hidden once trusted.
final class AXBanner: NSView {
    var onLayout: (() -> Void)?
    private let icon = NSImageView(), label = NSTextField(labelWithString: ""), button: NSButton, stack: NSStackView
    private var observer: NSObjectProtocol?
    init() {
        button = Glass.button("", prominent: true, target: nil, action: nil)
        stack = NSStackView(views: [icon, label, button]); stack.spacing = 8
        super.init(frame: .zero)
        let (g, c) = Glass.surface(radius: 17, tint: NSColor.systemYellow.withAlphaComponent(0.12)); g.frame = bounds; g.autoresizingMask = [.width, .height]; addSubview(g)
        label.font = .systemFont(ofSize: 12, weight: .medium); label.lineBreakMode = .byTruncatingTail
        icon.image = Glass.symbol("exclamationmark.triangle.fill", size: 13, weight: .semibold, color: .systemYellow)
        button.target = self; button.action = #selector(act)
        stack.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 14), stack.centerYAnchor.constraint(equalTo: c.centerYAnchor)])
        observer = NotificationCenter.default.addObserver(forName: .axChanged, object: nil, queue: .main) { [weak self] _ in self?.update() }
        update()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { observer.map(NotificationCenter.default.removeObserver) }
    @objc private func act() { AXMonitor.shared.state == .stale ? AXMonitor.relaunch() : AXMonitor.openSettings() }
    /// Re-read the state, hide when trusted, and resize to fit the text; `onLayout` lets the owner reposition.
    func update() {
        let s = AXMonitor.shared.state
        isHidden = s == .trusted
        label.stringValue = s == .stale ? "Accessibility is granted, but Pastry must relaunch to use it." : "Accessibility is off, so Pastry can't paste for you."
        button.title = s == .stale ? "Relaunch Pastry" : "Open Accessibility Settings"; button.sizeToFit()
        label.sizeToFit()
        setFrameSize(NSSize(width: 14 + 16 + 8 + label.frame.width + 8 + button.frame.width + 8, height: 34)); onLayout?()
    }
}
