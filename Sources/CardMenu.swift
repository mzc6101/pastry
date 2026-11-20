// Pastry: right-click context menu for cards (history and suggestions), the inline text editor, Quick Look and Share.
import AppKit
import QuickLookUI

/// Runs the closure stored on a menu item (plain NSMenuItems, so AppKit draws their symbol images natively).
final class MenuRunner: NSObject {
    static let shared = MenuRunner()
    @objc func fire(_ i: NSMenuItem) { (i.representedObject as? () -> Void)?() }
}
func ActionItem(_ title: String, _ symbol: String, key: String = "", mods: NSEvent.ModifierFlags = [], _ run: @escaping () -> Void) -> NSMenuItem {
    let i = NSMenuItem(title: title, action: #selector(MenuRunner.fire(_:)), keyEquivalent: key)
    i.keyEquivalentModifierMask = mods; i.target = MenuRunner.shared; i.representedObject = run
    // This macOS build does not draw NSMenuItem.image for our menus, so the symbol rides in the title as a text attachment.
    if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?.withSymbolConfiguration(.init(pointSize: 13, weight: .regular)) {
        let att = NSTextAttachment(); att.image = img; att.bounds = NSRect(x: 0, y: -2, width: img.size.width, height: img.size.height)
        let t = NSMutableAttributedString(attachment: att); t.append(NSAttributedString(string: "  " + title)); i.attributedTitle = t
    }
    return i
}

/// Text editor shown in a popover: monospaced for code-ish text, ⌘↩ saves, esc cancels.
final class EditorController: NSViewController {
    let tv = NSTextView(), text: String, onSave: (String) -> Void, onCancel: () -> Void
    init(text: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) { self.text = text; self.onSave = onSave; self.onCancel = onCancel; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 280)), sc = NSScrollView(frame: NSRect(x: 14, y: 54, width: 412, height: 212))
        let code = text.contains("{") || text.contains(";") || text.hasPrefix("/") || text.hasPrefix("$") || text.contains("    ")
        tv.string = text; tv.font = code ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 13); tv.isRichText = false; tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false; tv.isAutomaticDashSubstitutionEnabled = false; tv.autoresizingMask = .width; tv.textContainerInset = NSSize(width: 6, height: 6)
        sc.documentView = tv; sc.hasVerticalScroller = true; sc.borderType = .bezelBorder; sc.drawsBackground = true; v.addSubview(sc)
        let save = Glass.button("Save", prominent: true, target: self, action: #selector(save)); save.keyEquivalent = "\r"; save.keyEquivalentModifierMask = .command; save.toolTip = "Save (⌘↩)"
        let cancel = Glass.button("Cancel", target: self, action: #selector(cancel)); cancel.keyEquivalent = "\u{1b}"
        save.frame = NSRect(x: 340, y: 14, width: 86, height: 28); cancel.frame = NSRect(x: 248, y: 14, width: 86, height: 28)
        let hint = NSTextField(labelWithString: "⌘↩ Save   esc Cancel"); hint.font = .systemFont(ofSize: 11); hint.textColor = .tertiaryLabelColor; hint.frame = NSRect(x: 16, y: 20, width: 160, height: 16)
        [save, cancel, hint].forEach(v.addSubview); view = v
    }
    override func viewDidAppear() { super.viewDidAppear(); view.window?.makeFirstResponder(tv) }
    @objc func save() { onSave(tv.string) }
    @objc func cancel() { onCancel() }
}

extension Panel {
    var selectedRow: Store.Row? { inSide ? (ssel < sugg.count ? sugg[ssel] : nil) : (sel < rows.count ? rows[sel] : nil) }
    func fileURLs(_ id: Int64) -> [URL] {
        store.flavors(id).first { $0.0 == NSPasteboard.PasteboardType.fileURL.rawValue }.map { String(decoding: $0.1, as: UTF8.self).split(separator: "\n").compactMap { URL(string: String($0)) } } ?? []
    }
    func plainText(_ id: Int64) -> String? { store.flavors(id).first { $0.0 == NSPasteboard.PasteboardType.string.rawValue }.map { String(decoding: $0.1, as: UTF8.self) } }

    func menu(for card: CardView) -> NSMenu {
        if card.suggested { selectSide(card.index) } else { select(card.index) }
        let r = card.row, id = r.id, isText = r.kind == "text" || r.kind == "link", files = fileURLs(id), m = NSMenu()
        m.autoenablesItems = false; m.delegate = self
        m.addItem(ActionItem("Paste", "doc.on.clipboard", key: "\r") { [weak self] in self?.paste(id, plain: Prefs.plainPaste) })
        if isText { m.addItem(ActionItem("Paste as Plain Text", "textformat", key: "\r", mods: .shift) { [weak self] in self?.paste(id, plain: true) }) }
        m.addItem(ActionItem("Copy", "doc.on.doc") { [weak self] in guard let s = self else { return }; Injector.copy(flavors: s.store.flavors(id)) })
        if isText { m.addItem(ActionItem("Edit Text…", "pencil") { [weak self] in self?.editText(card) }) }
        m.addItem(ActionItem(r.pin == nil ? "Pin" : "Unpin", r.pin == nil ? "pin" : "pin.slash", key: "p", mods: .command) { [weak self] in self?.togglePin(id) })
        m.addItem(.separator())
        if r.kind == "link", let u = URL(string: r.preview.isEmpty ? r.title : r.preview) { m.addItem(ActionItem("Open", "safari") { NSWorkspace.shared.open(u) }) }
        else if !files.isEmpty { m.addItem(ActionItem("Open", "arrow.up.forward.app") { files.forEach { NSWorkspace.shared.open($0) } }) }
        if !files.isEmpty { m.addItem(ActionItem("Reveal in Finder", "folder") { NSWorkspace.shared.activateFileViewerSelecting(files) }) }
        if r.kind == "image" || r.kind == "file" { m.addItem(ActionItem("Quick Look", "eye", key: " ") { [weak self] in self?.quickLook(card) }) }
        m.addItem(ActionItem("Share…", "square.and.arrow.up") { [weak self] in self?.share(card) })
        m.addItem(.separator())
        m.addItem(ActionItem("Delete", "trash", key: "\u{8}") { [weak self] in self?.deleteItem(id) })
        return m
    }
    func menuWillOpen(_ menu: NSMenu) { holdOpen += 1 }
    func menuDidClose(_ menu: NSMenu) { DispatchQueue.main.async { [weak self] in self?.holdOpen -= 1 } }   // after the chosen action has run

    /// Re-run the query after a change, keeping the selection where it was.
    func refreshAfterChange() {
        let (i, j, side) = (sel, ssel, inSide)
        Suggest.invalidate(); reload()
        if side { selectSide(j) } else { select(min(i, max(0, cards.count - 1))) }
        refreshSuggestionsNow()
    }
    func togglePin(_ id: Int64) { store.togglePin(id); refreshAfterChange() }
    func deleteItem(_ id: Int64) { store.delete(id); refreshAfterChange() }

    func editText(_ card: CardView) {
        guard let text = plainText(card.row.id) ?? Optional(card.row.title) else { return }
        let id = card.row.id, pop = NSPopover(); popover = pop
        pop.behavior = .applicationDefined; pop.delegate = self; pop.animates = true
        pop.contentViewController = EditorController(text: text, onSave: { [weak self] t in
            self?.store.updateText(id, t); self?.popover?.close(); self?.refreshAfterChange()
        }, onCancel: { [weak self] in self?.popover?.close() })
        holdOpen += 1; pop.show(relativeTo: card.bounds, of: card, preferredEdge: .maxY)
    }
    func popoverDidClose(_ n: Notification) {
        popover = nil; DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }; s.holdOpen -= 1; s.makeKeyAndOrderFront(nil); s.makeFirstResponder(s.search) }
    }

    func share(_ card: CardView) {
        let id = card.row.id, files = fileURLs(id)
        var items: [Any] = files
        if items.isEmpty { if card.row.kind == "image", let p = tempImage(id) { items = [p] } else if let t = plainText(id) { items = [t] } }
        guard !items.isEmpty else { return }
        let picker = NSSharingServicePicker(items: items); picker.delegate = self; sharePicker = picker
        holdOpen += 1; picker.show(relativeTo: card.bounds, of: card, preferredEdge: .maxY)
    }
    func sharingServicePicker(_ p: NSSharingServicePicker, didChoose service: NSSharingService?) {
        DispatchQueue.main.async { [weak self] in self?.holdOpen -= 1; self?.sharePicker = nil }
    }
    func tempImage(_ id: Int64) -> URL? {
        guard let d = store.flavors(id).first(where: { $0.0 == NSPasteboard.PasteboardType.png.rawValue })?.1 else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("Pastry-\(id).png"); try? d.write(to: u); return u
    }

    func quickLook(_ card: CardView) {
        guard let url = fileURLs(card.row.id).first ?? tempImage(card.row.id) else { return }
        quickLookURL = url
        let ql = QLPreviewPanel.shared()!; ql.dataSource = self; ql.reloadData()
        holdOpen += 1
        let box = NSMutableArray()
        box.add(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: ql, queue: .main) { [weak self] _ in
            if let t = box.firstObject { NotificationCenter.default.removeObserver(t) }
            DispatchQueue.main.async { self?.holdOpen -= 1; self?.makeKeyAndOrderFront(nil); self?.makeFirstResponder(self?.search) } })
        ql.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { quickLookURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { quickLookURL as NSURL? }
}

extension Panel {
    /// Debug (PASTRY_AUTOMENU=menu|edit|editsave): open the context menu / editor on the first history card without synthesizing mouse events.
    func debugContext(_ what: String) {
        guard let c = cards.first else { return }
        switch what {
        case "menu": let m = menu(for: c); log("menu icons: \(m.items.map { $0.image != nil })"); m.popUp(positioning: nil, at: NSPoint(x: c.bounds.midX, y: c.bounds.midY), in: c)
        default:
            editText(c)
            if what == "editsave" { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let ed = self?.popover?.contentViewController as? EditorController else { return }
                ed.tv.string += " (edited)"; ed.save() } }
        }
    }
}
