// Pastry: clipboard history manager. No menu bar item: open the shelf with the hotkey; settings via the shelf's gear, ⌘, or by re-launching.
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store(path: Store.defaultPath)
    var monitor: Monitor!, panel: Panel!, settings: SettingsWindow!, hotKeys: HotKeyManager!

    func applicationDidFinishLaunching(_ n: Notification) {
        panel = Panel(store: store); panel.onSettings = { [unowned self] in showSettings() }
        monitor = Monitor(store: store); monitor.start()
        hotKeys = HotKeyManager { [unowned self] in panel.toggle() }
        settings = SettingsWindow(store: store, hotKeys: hotKeys) { [unowned self] in if panel.isVisible { panel.reload() } }
        installMenu()
        Onboarding.showIfNeeded()
        if let a = ProcessInfo.processInfo.environment["PASTRY_APPEARANCE"] { NSApp.appearance = NSAppearance(named: a == "dark" ? .darkAqua : .aqua) }   // debug: force light/dark
        store.enforce(); Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.store.enforce() }
        let ax = AXMonitor.shared.state == .trusted
        if !ax, !Prefs.axPrompted, ProcessInfo.processInfo.environment["PASTRY_NO_AX_PROMPT"] == nil {   // ask once; the shelf banner covers the rest
            Prefs.axPrompted = true; _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        }
        let st = hotKeys.register(Prefs.hotKey)
        if st != noErr { showSettings(); settings.reportHotKeyFailure(st, Prefs.hotKey) }
        if let t = ProcessInfo.processInfo.environment["PASTRY_AUTOSETTINGS"] { showSettings(); settings.tabs.selectedTabViewItemIndex = Int(t) ?? 0 }   // debug
        if let w = ProcessInfo.processInfo.environment["PASTRY_AUTOMENU"] { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.panel.debugContext(w) } }   // debug
        if ProcessInfo.processInfo.environment["PASTRY_AUTOSHOW"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.panel.show() } }
        log("running v\(appVersion) db=\(Store.defaultPath) items=\(store.count) ax=\(ax)")
    }
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool { showSettings(); return true }
    @objc func showSettings() { panel.close(); settings.present() }

    // Accessory apps show no menu bar, but this menu still provides ⌘, ⌘Q ⌘W and the editing shortcuts to whichever window is key.
    func installMenu() {
        let main = NSMenu()
        func add(_ title: String, _ items: [(String, Selector, String)]) {
            let m = NSMenu(title: title), top = NSMenuItem(title: title, action: nil, keyEquivalent: ""); top.submenu = m; main.addItem(top)
            for (t, a, k) in items { if t.isEmpty { m.addItem(.separator()) } else { m.addItem(withTitle: t, action: a, keyEquivalent: k) } }
        }
        add("Pastry", [("Settings…", #selector(showSettings), ","), ("", #selector(NSApplication.terminate(_:)), ""), ("Quit Pastry", #selector(NSApplication.terminate(_:)), "q")])
        add("Edit", [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"),
                     ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")])
        add("Window", [("Close", #selector(NSWindow.performClose(_:)), "w")])
        NSApp.mainMenu = main
    }
}

if CommandLine.arguments.contains("--ax-check") { exit(AXIsProcessTrusted() ? 0 : 1) }   // used by AXMonitor to see whether a grant exists for a fresh process
if CommandLine.arguments.contains("--dump") { // headless: list stored items (titles only)
    for r in Store(path: Store.defaultPath).search("") { print("\(r.id)\t\(r.kind)\t\(r.app)\t\(r.pin ?? "-")\t\(r.title)") }
    exit(0)
}
// Single instance: a second launch re-opens the running copy (→ settings) and exits. A relaunch waits for the old copy to quit first.
let others = { NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").filter { $0.processIdentifier != getpid() } }
if CommandLine.arguments.contains("--relaunch") { for _ in 0..<50 where !others().isEmpty { Thread.sleep(forTimeInterval: 0.1) } }
if let running = others().first {
    if let url = running.bundleURL { NSWorkspace.shared.open(url) }   // triggers applicationShouldHandleReopen in the running copy
    exit(0)
}
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
let del = AppDelegate(); app.delegate = del; app.run()
