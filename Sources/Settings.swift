// Pastry: settings window (General / Shortcuts / History) and the shortcut recorder control.
import AppKit
import Carbon.HIToolbox
import ServiceManagement

let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"

// Click, then press a combination (needs ⌘, ⌃ or ⌥). Esc cancels.
final class ShortcutRecorder: NSButton {
    var hotKey = HotKey.default { didSet { refresh() } }
    var onChange: ((HotKey) -> Void)?
    private var recording = false { didSet { refresh() } }
    override init(frame: NSRect) { super.init(frame: frame); Glass.style(self); target = self; action = #selector(begin); refresh() }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    private func refresh() { title = recording ? "Type shortcut…" : hotKey.display }
    @objc private func begin() { recording = true; window?.makeFirstResponder(self) }
    override func resignFirstResponder() -> Bool { recording = false; return super.resignFirstResponder() }
    override func performKeyEquivalent(with e: NSEvent) -> Bool { recording ? capture(e) : super.performKeyEquivalent(with: e) }
    override func keyDown(with e: NSEvent) { if !recording || !capture(e) { super.keyDown(with: e) } }
    private func capture(_ e: NSEvent) -> Bool {
        let mods = HotKey.carbonMods(e.modifierFlags)
        if e.keyCode == 53 && mods == 0 { recording = false; return true }
        guard mods & UInt32(cmdKey | controlKey | optionKey) != 0 else { NSSound.beep(); return true }
        recording = false; onChange?(HotKey(code: UInt32(e.keyCode), mods: mods)); return true
    }
}

final class SettingsWindow: NSWindow, NSTableViewDataSource, NSTableViewDelegate {
    let store: Store, hotKeys: HotKeyManager, onHistoryChanged: () -> Void
    let recorder = ShortcutRecorder(frame: .zero), hkStatus = NSTextField(wrappingLabelWithString: "")
    let loginBox = NSSwitch(), loginNote = NSTextField(wrappingLabelWithString: "")
    let table = NSTableView(), appField = NSTextField(), retention = NSPopUpButton(), maxField = NSTextField(), countLabel = NSTextField(labelWithString: "")
    let suggestBox = NSSwitch(), pinBox = NSSwitch(), banner = AXBanner(), tabs = NSTabViewController()
    private var pages: [NSViewController] = [], bannerRow: NSView?, holdingAX = false
    static let width: CGFloat = 540

    init(store: Store, hotKeys: HotKeyManager, onHistoryChanged: @escaping () -> Void) {
        self.store = store; self.hotKeys = hotKeys; self.onHistoryChanged = onHistoryChanged
        super.init(contentRect: NSRect(x: 0, y: 0, width: SettingsWindow.width, height: 480), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Pastry Settings"; isReleasedWhenClosed = false
        tabs.tabStyle = .toolbar
        for (name, symbol, content) in [("General", "gearshape", general()), ("Shortcuts", "command", shortcuts()), ("History", "clock.arrow.circlepath", history())] {
            let vc = NSViewController(); vc.view = content; vc.title = name; pages.append(vc)
            let item = NSTabViewItem(viewController: vc); item.label = name; item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: name); tabs.addTabViewItem(item)
        }
        contentViewController = tabs; fitPages(); center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: self, queue: .main) { [weak self] _ in self?.releaseAX() }
    }
    private func releaseAX() { if holdingAX { holdingAX = false; AXMonitor.shared.release() } }
    /// Size each tab to its content (the toolbar tab controller animates the window to the selected page's size).
    private func fitPages() {
        for vc in pages { vc.view.layoutSubtreeIfNeeded(); vc.preferredContentSize = NSSize(width: SettingsWindow.width, height: vc.view.fittingSize.height) }
        if let cur = tabs.selectedTabViewItemIndex >= 0 ? pages[tabs.selectedTabViewItemIndex] : nil, isVisible { setContentSize(cur.preferredContentSize) }
    }

    // MARK: layout helpers (grouped forms)
    private func page(_ views: [NSView]) -> NSView {
        let box = NSView(), s = NSStackView(views: views)
        s.orientation = .vertical; s.alignment = .leading; s.spacing = 16; s.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(s)
        NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: box.topAnchor, constant: 20), s.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -22),
                                     s.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 24), s.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -24)])
        for v in views { v.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true }
        return box
    }
    /// Rounded grouped section with an optional small header; rows separated by hairlines.
    private func group(_ title: String?, _ rows: [NSView]) -> NSView {
        let inner = NSStackView(), tile = Tile(radius: 14, fill: dyn(NSColor.black.withAlphaComponent(0.035), NSColor.white.withAlphaComponent(0.06)), border: dyn(NSColor.black.withAlphaComponent(0.07), NSColor.white.withAlphaComponent(0.09)))
        inner.orientation = .vertical; inner.alignment = .leading; inner.spacing = 0; inner.translatesAutoresizingMaskIntoConstraints = false
        for (i, r) in rows.enumerated() {
            if i > 0 { let sep = NSBox(); sep.boxType = .separator; inner.addArrangedSubview(sep); sep.widthAnchor.constraint(equalTo: inner.widthAnchor, constant: -28).isActive = true }
            inner.addArrangedSubview(r); r.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }
        tile.addSubview(inner)
        NSLayoutConstraint.activate([inner.topAnchor.constraint(equalTo: tile.topAnchor), inner.bottomAnchor.constraint(equalTo: tile.bottomAnchor),
                                     inner.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 14), inner.trailingAnchor.constraint(equalTo: tile.trailingAnchor)])
        guard let title else { return tile }
        let h = NSTextField(labelWithString: title.uppercased()); h.font = .systemFont(ofSize: 11, weight: .semibold); h.textColor = .secondaryLabelColor
        let s = NSStackView(views: [h, tile]); s.orientation = .vertical; s.alignment = .leading; s.spacing = 6
        h.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 6).isActive = true; tile.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
        return s
    }
    /// One form row: label (+ optional caption) on the left, control on the right.
    private func formRow(_ label: String, caption: String? = nil, _ control: NSView?) -> NSView {
        let l = NSTextField(labelWithString: label); l.font = .systemFont(ofSize: 13)
        let left = NSStackView(views: [l]); left.orientation = .vertical; left.alignment = .leading; left.spacing = 2
        if let c = caption { let n = NSTextField(wrappingLabelWithString: c); n.font = .systemFont(ofSize: 11); n.textColor = .secondaryLabelColor; n.preferredMaxLayoutWidth = 300; left.addArrangedSubview(n) }
        let r = NSStackView(views: [left, control ?? NSView()]); r.spacing = 12; r.alignment = .centerY; r.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 14)
        left.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal); r.distribution = .fill; control?.setContentHuggingPriority(.required, for: .horizontal)
        if control == nil { r.arrangedSubviews[1].isHidden = true }
        return r
    }
    private func note(_ t: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: t); l.font = .systemFont(ofSize: 11); l.textColor = .secondaryLabelColor
        l.preferredMaxLayoutWidth = SettingsWindow.width - 60; return l
    }
    private func button(_ t: String, _ a: Selector, prominent: Bool = false) -> NSButton { Glass.button(t, prominent: prominent, target: self, action: a) }
    private func bind(_ s: NSSwitch, _ a: Selector, _ on: Bool) -> NSSwitch { s.target = self; s.action = a; s.state = on ? .on : .off; return s }

    // MARK: General
    private func general() -> NSView {
        loginBox.target = self; loginBox.action = #selector(toggleLogin); loginNote.font = .systemFont(ofSize: 11); loginNote.textColor = .secondaryLabelColor
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))); table.headerView = nil; table.dataSource = self; table.delegate = self
        table.backgroundColor = .clear; table.style = .plain
        let sc = NSScrollView(); sc.documentView = table; sc.hasVerticalScroller = true; sc.drawsBackground = false; sc.borderType = .noBorder
        sc.heightAnchor.constraint(equalToConstant: 96).isActive = true
        appField.placeholderString = "com.example.app"; appField.controlSize = .regular; appField.bezelStyle = .roundedBezel
        let actions = NSStackView(views: [appField, button("Add", #selector(addApp)), button("Choose App…", #selector(chooseApp)), button("Remove", #selector(removeApp))])
        actions.spacing = 8; actions.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 14); appField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let about = NSTextField(labelWithString: "Pastry \(appVersion), a clipboard history manager.  © 2026 Manav Chordia"); about.font = .systemFont(ofSize: 11); about.textColor = .tertiaryLabelColor
        let foot = NSStackView(views: [about, button("Replay Onboarding…", #selector(replayOnboarding)), button("Quit Pastry", #selector(quit))]); foot.alignment = .centerY
        about.setContentHuggingPriority(.defaultLow, for: .horizontal)
        banner.translatesAutoresizingMaskIntoConstraints = false; banner.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let bannerBox = NSView(); bannerBox.addSubview(banner); bannerRow = bannerBox
        NSLayoutConstraint.activate([banner.leadingAnchor.constraint(equalTo: bannerBox.leadingAnchor), banner.topAnchor.constraint(equalTo: bannerBox.topAnchor), banner.bottomAnchor.constraint(equalTo: bannerBox.bottomAnchor), bannerBox.heightAnchor.constraint(equalToConstant: 34)])
        let bw = banner.widthAnchor.constraint(equalToConstant: 400); bw.isActive = true
        banner.onLayout = { [weak self] in
            guard let s = self else { return }
            bw.constant = s.banner.frame.width; s.bannerRow?.isHidden = s.banner.isHidden; s.fitPages() }
        return page([bannerBox,
                     group("Startup", [formRow("Launch Pastry at login", loginBox)]), loginNote,
                     group("Pasting", [formRow("Play sound on copy", bind(NSSwitch(), #selector(toggleSound(_:)), Prefs.playSound)),
                                       formRow("Paste as plain text by default", caption: "Hold ⇧ with Return to paste the other way.", bind(NSSwitch(), #selector(togglePlain(_:)), Prefs.plainPaste))]),
                     group("Suggestions", [formRow("Smart suggestions (on-device)", caption: Suggest.statusText, bind(suggestBox, #selector(toggleSuggest(_:)), Prefs.smartSuggestions))]),
                     group("Ignored apps (never recorded)", [sc, actions]), foot])
    }
    @objc func toggleSound(_ b: NSSwitch) { Prefs.playSound = b.state == .on }
    @objc func togglePlain(_ b: NSSwitch) { Prefs.plainPaste = b.state == .on }
    @objc func toggleSuggest(_ b: NSSwitch) { Prefs.smartSuggestions = b.state == .on }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func replayOnboarding() { Onboarding.show() }
    @objc func toggleLogin() {
        do { if loginBox.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { loginNote.stringValue = "Could not change login item: \(error.localizedDescription)" }
        refreshLogin()
    }
    func refreshLogin() {
        let st = SMAppService.mainApp.status
        loginBox.state = st == .enabled ? .on : .off
        loginNote.stringValue = st == .requiresApproval ? "Approve Pastry in System Settings > General > Login Items." : (loginNote.stringValue.hasPrefix("Could") ? loginNote.stringValue : "")
        loginNote.isHidden = loginNote.stringValue.isEmpty
    }
    func numberOfRows(in t: NSTableView) -> Int { Prefs.ignoredApps.count }
    func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row: Int) -> NSView? {
        let id = Prefs.ignoredApps[row], name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { FileManager.default.displayName(atPath: $0.path) }
        return NSTextField(labelWithString: name.map { "\($0)  (\(id))" } ?? id)
    }
    private func addIgnored(_ id: String) {
        let id = id.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !Prefs.ignoredApps.contains(id) else { return }
        Prefs.ignoredApps.append(id); table.reloadData(); appField.stringValue = ""
    }
    @objc func addApp() { addIgnored(appField.stringValue) }
    @objc func removeApp() {
        guard table.selectedRow >= 0 else { return }
        Prefs.ignoredApps.remove(at: table.selectedRow); table.reloadData()
    }
    @objc func chooseApp() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.application]; p.directoryURL = URL(fileURLWithPath: "/Applications"); p.prompt = "Ignore"
        p.beginSheetModal(for: self) { [weak self] r in if r == .OK, let id = p.url.flatMap({ Bundle(url: $0)?.bundleIdentifier }) { self?.addIgnored(id) } }
    }

    // MARK: Shortcuts
    private func shortcuts() -> NSView {
        recorder.hotKey = Prefs.hotKey; recorder.widthAnchor.constraint(equalToConstant: 150).isActive = true
        recorder.onChange = { [weak self] k in self?.apply(k) }
        hkStatus.font = .systemFont(ofSize: 11); hkStatus.preferredMaxLayoutWidth = SettingsWindow.width - 60; hkStatus.isHidden = true
        func key(_ k: String, _ d: String) -> NSView {
            let t = NSTextField(labelWithString: k); t.font = .monospacedSystemFont(ofSize: 12, weight: .medium); t.textColor = .secondaryLabelColor; return formRow(d, t) }
        return page([group("Show clipboard history", [formRow("Shortcut", NSStackView(views: [recorder, button("Reset to \(HotKey.default.display)", #selector(resetHotKey))]))]), hkStatus,
                     note("Click the shortcut, then press the new combination (it needs ⌘, ⌃ or ⌥). Esc cancels. Changes apply immediately."),
                     group("In the shelf", [key("↩", "Paste"), key("⇧↩", "Paste the other way (plain / rich)"), key("⌘1 – ⌘9", "Paste a card"), key("⌘P", "Pin or unpin"),
                                            key("⇥", "Switch Clipboard / Pinned"), key("⇧→ / ⇧←", "Jump to suggestions / back to history"), key("⌫", "Delete the selected card"), key("right-click", "Card menu"), key("⌘,", "Settings"), key("esc", "Close")])])
    }
    @objc func resetHotKey() { apply(.default) }
    func apply(_ k: HotKey) {
        let st = hotKeys.register(k); hkStatus.isHidden = false
        if st == noErr { Prefs.hotKey = k; recorder.hotKey = k; hkStatus.textColor = .secondaryLabelColor; hkStatus.stringValue = "Saved: \(k.display)" }
        else { recorder.hotKey = hotKeys.current ?? Prefs.hotKey; hkStatus.textColor = .systemRed
            hkStatus.stringValue = HotKeyManager.explain(st, k) + " Still using \(recorder.hotKey.display)." }
    }
    func reportHotKeyFailure(_ st: OSStatus, _ k: HotKey) { hkStatus.isHidden = false; hkStatus.textColor = .systemRed; hkStatus.stringValue = HotKeyManager.explain(st, k) + " Pick another shortcut." }

    // MARK: History
    private func history() -> NSView {
        for (t, d) in [("1 day", 1), ("1 week", 7), ("1 month", 30), ("1 year", 365), ("Forever", 0)] { retention.addItem(withTitle: t); retention.lastItem?.tag = d }
        retention.target = self; retention.action = #selector(retentionChanged)
        let f = NumberFormatter(); f.minimum = 10; f.maximum = 1_000_000; f.allowsFloats = false
        maxField.formatter = f; maxField.target = self; maxField.action = #selector(maxChanged); maxField.alignment = .right; maxField.bezelStyle = .roundedBezel; maxField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        pinBox.target = self; pinBox.action = #selector(pinChanged)
        countLabel.font = .systemFont(ofSize: 12); countLabel.textColor = .secondaryLabelColor
        return page([group("Retention", [formRow("Keep history for", retention), formRow("Maximum items", caption: "The oldest are removed first.", maxField),
                                         formRow("Keep pinned items when clearing", caption: "Applies to automatic cleanup and to “Clear history now”.", pinBox)]),
                     group(nil, [formRow("Stored", countLabel), formRow("Clear history", button("Clear history now…", #selector(clearNow)))])])
    }
    @objc func retentionChanged() { Prefs.retentionDays = retention.selectedItem?.tag ?? 0; enforceAndRefresh() }
    @objc func maxChanged() { Prefs.maxItems = max(10, maxField.integerValue); maxField.integerValue = Prefs.maxItems; enforceAndRefresh() }
    @objc func pinChanged() { Prefs.keepPinned = pinBox.state == .on; enforceAndRefresh() }
    private func enforceAndRefresh() { store.enforce(); refreshHistory(); onHistoryChanged() }
    func refreshHistory() {
        retention.selectItem(withTag: Prefs.retentionDays); maxField.integerValue = Prefs.maxItems; pinBox.state = Prefs.keepPinned ? .on : .off
        countLabel.stringValue = "\(store.count) item\(store.count == 1 ? "" : "s") stored"
    }
    @objc func clearNow() {
        let a = NSAlert(); a.alertStyle = .warning; a.messageText = "Clear clipboard history?"
        a.informativeText = Prefs.keepPinned ? "All items except pinned ones will be deleted. This cannot be undone." : "All items, including pinned ones, will be deleted. This cannot be undone."
        a.addButton(withTitle: "Clear"); a.addButton(withTitle: "Cancel")
        a.beginSheetModal(for: self) { [weak self] r in
            guard r == .alertFirstButtonReturn, let s = self else { return }
            s.store.clearAll(); s.refreshHistory(); s.onHistoryChanged()
        }
    }

    func present() {
        refreshLogin(); refreshHistory(); table.reloadData(); suggestBox.state = Prefs.smartSuggestions ? .on : .off
        if !holdingAX { holdingAX = true; AXMonitor.shared.hold() }
        banner.update(); fitPages()
        makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); log("settings shown")
    }
}
