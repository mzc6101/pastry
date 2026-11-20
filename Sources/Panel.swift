// Pastry: the shelf (bottom-of-screen, blurred, horizontal card row) with auto-close behaviour.
import AppKit
import QuickLookUI

final class Panel: NSPanel, NSTextFieldDelegate, NSMenuDelegate, NSPopoverDelegate, NSSharingServicePickerDelegate, QLPreviewPanelDataSource {
    let store: Store; let search = NSTextField(); let scroll = NSScrollView(); let doc = NSView(); let hint = NSTextField(labelWithString: "")
    let banner = AXBanner(), seg = PillSegmented(items: [("Clipboard", "doc.on.clipboard"), ("Pinned", "pin.fill")], frame: NSRect(x: 0, y: 0, width: 232, height: 34))
    var rows: [Store.Row] = []; var cards: [CardView] = []; var sel = 0; var target: NSRunningApplication?; var pinOnly = false
    var onSettings: (() -> Void)?
    var holdOpen = 0, popover: NSPopover?, sharePicker: NSSharingServicePicker?, quickLookURL: URL?   // holdOpen > 0: a menu / editor / picker owns focus, so never auto-close
    // suggestions: the right-most 3 tiles, behind a divider; ignored by search / pin filter
    let side = NSView(), divider = NSBox(), fade = CAGradientLayer(), sideTitle = NSTextField(labelWithString: ""), sparkle = NSButton()
    var sugg: [Store.Row] = [], sugCards: [CardView] = [], ssel = 0, inSide = false
    static let sideWidth: CGFloat = 1 + 12 + 3 * (CardView.size.width + 2) + 12   // divider, gap, 3 tiles, margin
    private var monitors: [Any] = [], observers: [(NotificationCenter, NSObjectProtocol)] = [], holdingAX = false, closeToken = 0, closing = false
    static let height: CGFloat = 372
    private var body = NSView()

    init(store: Store) {
        self.store = store
        let W: CGFloat = 1200, H = Panel.height, bw = W, bh = H, top = bh - 14 - 34
        super.init(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating; isOpaque = false; backgroundColor = .clear; hasShadow = true; isReleasedWhenClosed = false
        hidesOnDeactivate = false; collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // edge-to-edge frosted glass along the bottom of the screen (the tint keeps whatever is behind from reading through)
        let frost = dyn(NSColor.white.withAlphaComponent(0.55), NSColor.black.withAlphaComponent(0.45))
        let (glass, content) = Glass.surface(radius: 22, tint: frost, material: .hudWindow); body = content
        glass.frame = NSRect(x: 0, y: 0, width: bw, height: bh); glass.autoresizingMask = [.width, .height]
        let root = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H)); root.addSubview(glass); contentView = root
        content.frame = NSRect(x: 0, y: 0, width: bw, height: bh)
        // search: glass capsule with a magnifier
        let (sBox, sIn) = Glass.surface(radius: 17); sBox.frame = NSRect(x: 22, y: top, width: 250, height: 34); sBox.autoresizingMask = [.minYMargin]
        let mag = NSImageView(image: Glass.symbol("magnifyingglass", size: 13, weight: .medium, color: .secondaryLabelColor) ?? NSImage()); mag.frame = NSRect(x: 12, y: 8, width: 18, height: 18)
        search.placeholderString = "Search"; search.delegate = self; search.isBordered = false; search.drawsBackground = false; search.focusRingType = .none
        search.font = .systemFont(ofSize: 14); search.frame = NSRect(x: 36, y: 8, width: 200, height: 18); search.cell?.isScrollable = true
        sIn.addSubview(mag); sIn.addSubview(search); content.addSubview(sBox)
        seg.frame.origin = NSPoint(x: 288, y: top); seg.autoresizingMask = [.minYMargin]; seg.onChange = { [weak self] i in self?.pinOnly = i == 1; self?.reload() }; content.addSubview(seg)
        let gear = NSButton(image: Glass.symbol("gearshape", size: 14, weight: .medium) ?? NSImage(), target: self, action: #selector(openSettings))
        Glass.style(gear, circle: true); gear.imagePosition = .imageOnly; gear.toolTip = "Settings (⌘,)"
        gear.frame = NSRect(x: bw - 22 - 34, y: top, width: 34, height: 34); gear.autoresizingMask = [.minXMargin, .minYMargin]; content.addSubview(gear)
        hint.stringValue = "↩ Paste   ⇧↩ Plain   ⌘P Pin   ⇥ Filter   ⇧→ Suggested   esc Close"; hint.font = .systemFont(ofSize: 11, weight: .medium); hint.textColor = .tertiaryLabelColor
        hint.alignment = .right; hint.frame = NSRect(x: bw - 22 - 76 - 14 - 420, y: top + 9, width: 420, height: 16); hint.autoresizingMask = [.minXMargin, .minYMargin]; content.addSubview(hint)
        sparkle.target = self; sparkle.action = #selector(toggleSuggestions); sparkle.imagePosition = .imageOnly; Glass.style(sparkle, circle: true)
        sparkle.frame = NSRect(x: bw - 22 - 34 - 8 - 34, y: top, width: 34, height: 34); sparkle.autoresizingMask = [.minXMargin, .minYMargin]; content.addSubview(sparkle)
        banner.onLayout = { [weak self] in self?.layoutBanner() }; banner.autoresizingMask = [.minXMargin, .minYMargin]; content.addSubview(banner)
        scroll.frame = NSRect(x: 0, y: 6, width: bw, height: bh - 64); scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false; scroll.hasHorizontalScroller = true; scroll.autohidesScrollers = true; scroll.documentView = doc
        content.addSubview(scroll)
        divider.boxType = .separator; fade.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]; fade.startPoint = CGPoint(x: 0, y: 0.5); fade.endPoint = CGPoint(x: 1, y: 0.5)
        scroll.wantsLayer = true
        side.wantsLayer = true; side.autoresizingMask = [.minXMargin, .height]; divider.autoresizingMask = [.minXMargin, .height]
        side.addSubview(sideTitle)
        content.addSubview(divider); content.addSubview(side); syncSparkle()
        NotificationCenter.default.addObserver(forName: .axChanged, object: nil, queue: .main) { [weak self] _ in self?.syncBanner() }
    }
    override var canBecomeKey: Bool { true }
    @objc func openSettings() { close(); onSettings?() }
    private func layoutBanner() {   // right-aligned, sized to its text, replaces the key hint
        banner.frame.origin = NSPoint(x: body.bounds.width - 22 - 76 - 14 - banner.frame.width, y: body.bounds.height - 14 - 34)
        hint.isHidden = !banner.isHidden
    }
    private func syncBanner() { banner.update() }
    func toggle() { isVisible && !closing ? close() : show() }
    func show() {
        closeToken += 1; target = NSWorkspace.shared.frontmostApplication
        if !holdingAX { holdingAX = true; AXMonitor.shared.hold() }
        let scr = NSScreen.main ?? NSScreen.screens[0], vf = scr.visibleFrame   // visibleFrame sits above the Dock
        let end = NSRect(x: scr.frame.minX, y: vf.minY, width: scr.frame.width, height: Panel.height)
        if !isVisible { setFrame(end.offsetBy(dx: 0, dy: -60), display: false); alphaValue = 0 }
        closing = false; search.stringValue = ""; pinOnly = false; seg.index = 0; layoutRegions(end.width); reload(); refreshSuggestions()
        makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); makeFirstResponder(search)
        banner.update(); layoutBanner()
        NSAnimationContext.runAnimationGroup { c in c.duration = 0.34; c.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1); animator().setFrame(end, display: true); animator().alphaValue = 1 }
        log("shelf shown (ax=\(AXMonitor.shared.state))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in if self?.isVisible == true { self?.armAutoClose() } }
    }

    // MARK: auto-close. The panel never owns the app's activation, so watch every way focus can leave it.
    private func armAutoClose() {
        disarm()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] e in self?.dismiss("click outside at \(e.locationInWindow) type \(e.type.rawValue) window \(e.windowNumber)") }) { monitors.append(m) }     // other apps
        if let m = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] e in   // our own other windows
            if let s = self, let w = e.window, w !== s { s.dismiss("click in another Pastry window") }; return e }) { monitors.append(m) }
        let ws = NSWorkspace.shared.notificationCenter, nc = NotificationCenter.default
        observers.append((ws, ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let a = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if a?.processIdentifier != getpid() { self?.dismiss("another app activated (\(a?.bundleIdentifier ?? "?"))") } }))
        observers.append((nc, nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.dismiss("app resigned active") }))
        observers.append((nc, nc.addObserver(forName: NSWindow.didResignKeyNotification, object: self, queue: .main) { [weak self] _ in self?.dismiss("shelf lost key") }))
    }
    private func disarm() {
        monitors.forEach { NSEvent.removeMonitor($0) }; monitors = []
        observers.forEach { $0.0.removeObserver($0.1) }; observers = []
    }
    func dismiss(_ why: String) { guard isVisible, !closing, holdOpen == 0 else { return }; log("shelf closed: \(why)"); close() }
    override func close() {
        disarm(); Suggest.cancel(); if holdingAX { holdingAX = false; AXMonitor.shared.release() }
        guard isVisible, !closing else { return }
        closing = true; closeToken += 1; let token = closeToken
        NSAnimationContext.runAnimationGroup({ c in c.duration = 0.18; c.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrame(frame.offsetBy(dx: 0, dy: -40), display: true); animator().alphaValue = 0 },
            completionHandler: { [weak self] in if let s = self, s.closeToken == token { s.closing = false; s.orderOut(nil) } })
    }

    func reload() {
        rows = store.search(search.stringValue, pinboard: pinOnly ? "" : nil)
        seg.index = pinOnly ? 1 : 0
        cards.forEach { $0.removeFromSuperview() }
        let s = CardView.size, h = scroll.frame.height
        cards = rows.enumerated().map { i, r in
            let c = CardView(row: r, index: i, store: store); c.frame.origin = NSPoint(x: 17 + CGFloat(i) * (s.width + 2), y: max(0, (h - s.height) / 2))
            c.onClick = { [weak self] i, n in self?.select(i); if n >= 2 { self?.choose() } }; c.onMenu = { [weak self] in self?.menu(for: $0) }; doc.addSubview(c); return c }
        doc.frame = NSRect(x: 0, y: 0, width: max(scroll.frame.width, 34 + CGFloat(rows.count) * (s.width + 2)), height: h)
        sel = 0; select(0)
    }
    func select(_ i: Int) {
        inSide = false; syncSelection()
        guard !cards.isEmpty else { return }
        sel = max(0, min(cards.count - 1, i)); syncSelection()
        doc.scrollToVisible(cards[sel].frame.insetBy(dx: -14, dy: 0))
    }
    func selectSide(_ i: Int) { guard !sugg.isEmpty else { return }; inSide = true; ssel = max(0, min(sugg.count - 1, i)); syncSelection() }
    private func syncSelection() {
        cards.enumerated().forEach { $0.element.selected = !inSide && $0.offset == sel }
        sugCards.enumerated().forEach { $0.element.selected = inSide && $0.offset == ssel }
    }

    // MARK: suggestions
    private var suggestionsOn: Bool { Prefs.smartSuggestions }
    private func syncSparkle() {
        let on = suggestionsOn
        sparkle.image = Glass.symbol("sparkles", size: 14, weight: .medium, color: on ? .white : nil); sparkle.bezelColor = on ? .controlAccentColor : nil
        sparkle.toolTip = on ? "Smart suggestions on" : "Smart suggestions off"
    }
    @objc private func toggleSuggestions() {
        Prefs.smartSuggestions.toggle(); syncSparkle()
        let on = suggestionsOn, animated = isVisible && !closing
        if on { refreshSuggestions() }   // builds the tiles (heuristic / cached result arrives synchronously)
        applyRegions(frame.width, animated: animated, onTiles: on ? .appear : .vanish)
        if !on { Suggest.cancel() }
    }
    private enum Tiles { case none, appear, vanish }
    /// History fills the left; the 3 suggestion tiles (when enabled) sit in a fixed region on the right behind a divider.
    /// Divider has 16pt of air on both sides; the history edge fades out instead of hard-clipping.
    private func layoutRegions(_ w: CGFloat) { applyRegions(w, animated: false, onTiles: .none) }
    private func applyRegions(_ w: CGFloat, animated: Bool, onTiles: Tiles) {
        let on = suggestionsOn, h = body.bounds.height - 64, sx = w - Panel.sideWidth, reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let scrollF = NSRect(x: 0, y: 6, width: on ? sx - 16 : w, height: h)
        let sideF = NSRect(x: sx, y: 6, width: Panel.sideWidth, height: h), divF = NSRect(x: sx, y: 22, width: 1, height: h - 32)
        sideTitle.frame = NSRect(x: 17, y: h - 20, width: Panel.sideWidth - 30, height: 15)
        func finish() {
            let s = CardView.size
            doc.frame.size.width = max(scrollF.width, 34 + CGFloat(rows.count) * (s.width + 2))
            if !on { side.isHidden = true; divider.isHidden = true; scroll.layer?.mask = nil; refreshSuggestions() }
        }
        func setFade(_ width: CGFloat) { fade.frame = CGRect(x: 0, y: 0, width: width, height: h); let f = max(0, (width - 32) / max(width, 1)); fade.locations = [0, NSNumber(value: Double(f)), 1] }
        guard animated else {
            scroll.frame = scrollF; side.frame = sideF; divider.frame = divF; side.isHidden = !on; divider.isHidden = !on; divider.alphaValue = 1
            if on { setFade(scrollF.width); scroll.layer?.mask = fade } else { scroll.layer?.mask = nil }
            finish(); return
        }
        if on {
            side.isHidden = false; divider.isHidden = false; side.frame = sideF; divider.frame = divF; divider.alphaValue = 0; sideTitle.alphaValue = 0
            CATransaction.begin(); CATransaction.setDisableActions(true); setFade(scroll.frame.width); scroll.layer?.mask = fade; CATransaction.commit()
        }
        for (i, c) in sugCards.enumerated() { c.animate(appear: on, delay: reduce ? 0 : Double(i) * 0.05, reduce: reduce) }
        let dur = reduce ? 0.2 : 0.38, timing = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.3, 1)
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = dur; c.timingFunction = timing; c.allowsImplicitAnimation = true
            CATransaction.setAnimationDuration(dur); CATransaction.setAnimationTimingFunction(timing)
            if reduce { scroll.frame = scrollF } else { scroll.animator().frame = scrollF }
            setFade(scrollF.width); divider.animator().alphaValue = on ? 1 : 0; sideTitle.animator().alphaValue = on ? 1 : 0
        }, completionHandler: { finish() })
    }
    func refreshSuggestionsNow() { refreshSuggestions() }
    private func refreshSuggestions() {
        guard suggestionsOn else { Suggest.cancel(); sugg = []; sugCards.forEach { $0.removeFromSuperview() }; sugCards = []; return }
        let app = target; let name = app?.localizedName ?? "this app"
        Suggest.request(app: app, rows: rows) { [weak self] picks, src in self?.showSuggestions(picks, src, appName: name) }
    }
    private func showSuggestions(_ picks: [Store.Row], _ src: Suggest.Source, appName: String) {
        guard suggestionsOn, isVisible || !closing else { return }
        if picks.map(\.id) != sugg.map(\.id), !sugCards.isEmpty {   // late model result: subtle cross-fade
            let t = CATransition(); t.type = .fade; t.duration = 0.25; side.layer?.add(t, forKey: "swap")
        }
        sugg = picks; sugCards.forEach { $0.removeFromSuperview() }
        let s = CardView.size, y = max(0, (side.frame.height - s.height) / 2)   // same top/bottom as the history cards
        sugCards = picks.enumerated().map { i, r in
            let c = CardView(row: r, index: i, store: store); c.suggested = true; c.frame.origin = NSPoint(x: 12 + CGFloat(i) * (s.width + 2), y: y)
            c.onClick = { [weak self] i, n in self?.selectSide(i); if n >= 2 { self?.choose() } }; c.onMenu = { [weak self] in self?.menu(for: $0) }; side.addSubview(c); return c }
        let title = NSMutableAttributedString()
        if let img = Glass.symbol("sparkles", size: 11, weight: .semibold, color: .controlAccentColor) {
            let a = NSTextAttachment(); a.image = img; a.bounds = NSRect(x: 0, y: -2, width: img.size.width, height: img.size.height); title.append(NSAttributedString(attachment: a)); title.append(NSAttributedString(string: " "))
        }
        title.append(NSAttributedString(string: "Suggested for \(appName)", attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor]))
        title.append(NSAttributedString(string: "   \(src.rawValue)", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.tertiaryLabelColor]))
        sideTitle.attributedStringValue = title; sideTitle.lineBreakMode = .byTruncatingTail
        if inSide { ssel = min(ssel, max(0, sugg.count - 1)); if sugg.isEmpty { inSide = false } }
        syncSelection()
    }
    func controlTextDidChange(_ n: Notification) { reload() }
    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        let empty = search.stringValue.isEmpty
        switch sel {
        case #selector(NSResponder.insertNewline(_:)): choose(invertPlain: NSApp.currentEvent?.modifierFlags.contains(.shift) == true); return true
        case #selector(NSResponder.moveRightAndModifySelection(_:)), #selector(NSResponder.moveToEndOfLine(_:)):   // ⇧→ / ⌘→: first suggestion tile, unless the caret is mid-text
            guard empty || (c as? NSTextField)?.currentEditor()?.selectedRange.upperBound == search.stringValue.count else { return false }
            if sel == #selector(NSResponder.moveToEndOfLine(_:)), !suggestionsOn { toggleSuggestions() }   // ⌘→ also opens the suggestions if they're off
            guard !sugg.isEmpty else { return false }
            selectSide(0); return true
        case #selector(NSResponder.moveLeftAndModifySelection(_:)) where inSide, #selector(NSResponder.moveToBeginningOfLine(_:)) where inSide: select(self.sel); return true   // ⇧← (⌘←): back to history
        case #selector(NSResponder.moveRight(_:)) where empty, #selector(NSResponder.moveDown(_:)):
            if inSide { selectSide(ssel + 1) } else if self.sel >= cards.count - 1, !sugg.isEmpty { selectSide(0) } else { select(self.sel + 1) }; return true
        case #selector(NSResponder.moveLeft(_:)) where empty, #selector(NSResponder.moveUp(_:)):
            if inSide { ssel == 0 ? select(self.sel) : selectSide(ssel - 1) } else { select(self.sel - 1) }; return true
        case #selector(NSResponder.deleteBackward(_:)) where empty: if let r = selectedRow { deleteItem(r.id) }; return true
        case #selector(NSResponder.cancelOperation(_:)): close(); return true
        case #selector(NSResponder.insertTab(_:)): pinOnly.toggle(); reload(); return true
        default: return false }
    }
    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        if e.modifierFlags.contains(.command), let k = e.charactersIgnoringModifiers {
            if k == "p", !rows.isEmpty { let r = sel; store.togglePin(rows[r].id); reload(); select(r); return true }
            if let n = Int(k), n >= 1, n <= min(9, rows.count) { select(n - 1); choose(); return true }
        }
        return super.performKeyEquivalent(with: e)
    }
    func choose(invertPlain: Bool = false) {
        guard inSide ? ssel < sugg.count : sel < rows.count else { return }
        paste(inSide ? sugg[ssel].id : rows[sel].id, plain: Prefs.plainPaste != invertPlain)
    }
    func paste(_ id: Int64, plain: Bool) { close(); Injector.paste(flavors: store.flavors(id), into: target, plain: plain) }
}
