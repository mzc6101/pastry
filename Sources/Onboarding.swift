// Pastry: first-launch onboarding. Window + live engine (this file); screens in OnboardingScreens.swift, motion in OnboardingFX.swift.
// Everything is torn down when the window closes: timers, observers, the AX hold and the SwiftUI tree.
import AppKit
import SwiftUI
import ServiceManagement

enum Onboarding {
    static var controller: OnbController?
    static var done: Bool { Prefs.d.bool(forKey: "onboardingDone") }
    /// First launch only (PASTRY_ONBOARDING=1 forces it).
    static func showIfNeeded() {
        if ProcessInfo.processInfo.environment["PASTRY_ONBOARDING"] != nil || !done || Prefs.d.object(forKey: "onboardingResume") != nil { show() }
    }
    static func show() {
        if let c = controller { c.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        log("onboarding: show"); let c = OnbController(); controller = c; c.present(); log("onboarding: presented \(c.window.frame)")
    }
}

struct OnbClip: Identifiable {
    let id = UUID()
    var kind: String, title: String, meta: String, app: String
    var image: NSImage?
}

final class OnbModel: ObservableObject {
    enum Step: Int, CaseIterable { case welcome, copy, shelf, suggest, access, finish }
    @Published var step = Step(rawValue: Int(ProcessInfo.processInfo.environment["PASTRY_ONB_STEP"] ?? "") ?? Prefs.d.integer(forKey: "onboardingResume")) ?? .welcome   // a relaunch during the permission step resumes there
    @Published var forward = true
    @Published var active = true                 // window visible and not occluded: gates every animation clock
    @Published var clips: [OnbClip] = []
    @Published var shelfOpened = false
    @Published var ax = AXMonitor.shared.state
    @Published var axGranted = false             // granted while the user watched (drives the celebration)
    @Published var loginOn = SMAppService.mainApp.status == .enabled
    @Published var burst: Date?
    @Published var jumped = false                 // suggestions step: selection ring is on the first suggestion
    @Published var hint = false                   // shown after a while with no action on the copy / shelf steps
    @Published var front: (name: String, bundle: String, icon: NSImage?)
    let hotkey = Prefs.hotKey.display
    var close: () -> Void = {}

    private var pollTimer: Timer?, baseline = 0, observers: [(NotificationCenter, NSObjectProtocol)] = [], holdingAX = false
    private var lastApp: NSRunningApplication?, advanceToken = 0

    init() {
        let me = Bundle.main.bundleIdentifier
        let a = NSWorkspace.shared.frontmostApplication.flatMap { $0.bundleIdentifier == me ? nil : $0 }
            ?? NSWorkspace.shared.runningApplications.first { $0.activationPolicy == .regular && $0.bundleIdentifier != me && $0.isActive == false && $0.bundleIdentifier != "com.apple.finder" }
        front = (a?.localizedName ?? "your app", a?.bundleIdentifier ?? "", a?.icon)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didActivateApplicationNotification) { [weak self] n in
            guard let s = self, let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.bundleIdentifier != me, app.activationPolicy == .regular else { return }
            s.lastApp = app; s.front = (app.localizedName ?? "your app", app.bundleIdentifier ?? "", app.icon)
        }
        observe(.default, NSWindow.didBecomeKeyNotification) { [weak self] n in   // the real shelf appearing == the user pressed the hotkey
            if n.object is Panel { self?.shelfShown() }
        }
        observe(.default, .axChanged) { [weak self] _ in self?.axChanged() }
        Prefs.d.removeObject(forKey: "onboardingResume"); enter()
    }
    private func observe(_ c: NotificationCenter, _ name: Notification.Name, _ f: @escaping (Notification) -> Void) {
        observers.append((c, c.addObserver(forName: name, object: nil, queue: .main, using: f)))
    }

    private var burstToken = 0
    func celebrate() {
        burst = Date(); burstToken += 1; let t = burstToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in if self?.burstToken == t { self?.burst = nil } }
    }

    // MARK: navigation
    var count: Int { Step.allCases.count }
    func go(_ s: Step) { guard s != step else { return }; leave(); advanceToken += 1; forward = s.rawValue > step.rawValue; step = s; enter() }
    func next() { if let n = Step(rawValue: step.rawValue + 1) { go(n) } else { finish() } }
    func back() { if let p = Step(rawValue: step.rawValue - 1) { go(p) } }
    func finish() {
        Prefs.d.set(true, forKey: "onboardingDone"); celebrate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.close()   // then the shelf rises once to say hello
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { (NSApp.delegate as? AppDelegate)?.panel.show() }
        }
    }

    private func enter() {
        hint = false; jumped = false
        if step == .suggest { let t = advanceToken; DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in if let s = self, s.advanceToken == t, !s.jumped, !s.demoed { s.jump(true) } } }   // auto-demo once
        let wait: Double = step == .copy ? 20 : step == .shelf ? 30 : 0, token = advanceToken
        if wait > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in if let s = self, s.advanceToken == token { withAnimation(onbSpring()) { s.hint = true } } } }
        if step == .shelf, ProcessInfo.processInfo.environment["PASTRY_ONB_AUTOSHELF"] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.showShelfForMe() } }   // debug
        switch step {
        case .copy:
            baseline = NSPasteboard.general.changeCount
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.poll() }
        case .access:
            axGranted = false; AXMonitor.shared.hold(); holdingAX = true; ax = AXMonitor.shared.state
        case .finish: loginOn = SMAppService.mainApp.status == .enabled
        default: break
        }
    }
    private func leave() {
        pollTimer?.invalidate(); pollTimer = nil
        if holdingAX { holdingAX = false; AXMonitor.shared.release() }
    }
    /// Called when the window closes: nothing may keep running afterwards.
    func teardown() {
        leave(); active = false; advanceToken += 1
        for (c, o) in observers { c.removeObserver(o) }
        observers = []
        (NSApp.delegate as? AppDelegate)?.panel.close()
    }

    // MARK: live detection
    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != baseline else { return }
        baseline = pb.changeCount
        guard Set(pb.types?.map(\.rawValue) ?? []).isDisjoint(with: Capture.skipTypes), let c = Capture.clip(from: pb) else { return }
        var img: NSImage?
        if c.kind == "image", let d = c.flavors.first(where: { $0.0 == NSPasteboard.PasteboardType.png.rawValue || $0.0 == thumbUTI })?.1 { img = NSImage(data: d) }
        let clip = OnbClip(kind: c.kind, title: c.title, meta: c.meta, app: front.name, image: img)
        withAnimation(onbSpring(0.7, 0.68)) { clips.insert(clip, at: 0); if clips.count > 3 { clips.removeLast() } }
        celebrate()
    }
    private func shelfShown() {
        guard step == .shelf, !shelfOpened else { return }
        withAnimation(onbSpring(0.8, 0.72)) { shelfOpened = true }
        celebrate()
        let token = advanceToken
        // let them see the real shelf, then hand over to the morphed glass one and move on
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let s = self, s.advanceToken == token else { return }
            (NSApp.delegate as? AppDelegate)?.panel.close(); Onboarding.controller?.window.makeKeyAndOrderFront(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let s = self, s.advanceToken == token, s.step == .shelf else { return }
            s.next()
        }
    }
    func showShelfForMe() { (NSApp.delegate as? AppDelegate)?.panel.show() }
    private func axChanged() {
        guard step == .access else { return }
        let was = ax; ax = AXMonitor.shared.state
        guard ax != .missing, was == .missing else { return }
        withAnimation(onbSpring(0.6, 0.7)) { axGranted = true }
        celebrate()
        let token = advanceToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let s = self, s.advanceToken == token, s.step == .access else { return }
            s.next()
        }
    }
    func relaunch() { Prefs.d.set(Step.access.rawValue, forKey: "onboardingResume"); AXMonitor.relaunch() }
    private var demoed = false
    /// ⇧→ / ⇧← on the suggestions step.
    func jump(_ toSuggestions: Bool) {
        guard step == .suggest else { return }
        demoed = true
        withAnimation(onbSpring(0.7, 0.8)) { jumped = toSuggestions }
    }
    func openAccessibility() { AXMonitor.openSettings() }

    func setLogin(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch { log("onboarding login item: \(error.localizedDescription)") }
        loginOn = SMAppService.mainApp.status == .enabled
    }
    static let sampleText = "The quick brown fox jumps over the lazy dog.", sampleLink = "https://www.apple.com/macos"
    static let sampleImage: NSImage = NSImage(size: NSSize(width: 240, height: 160), flipped: false) { r in
        NSGradient(colors: [.systemPink, .systemOrange, .systemYellow])?.draw(in: r, angle: 35)
        NSColor.white.withAlphaComponent(0.85).setFill(); NSBezierPath(ovalIn: NSRect(x: 150, y: 90, width: 46, height: 46)).fill()
        NSColor.white.withAlphaComponent(0.55).setFill(); NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 240, height: 44), xRadius: 0, yRadius: 0).fill(); return true
    }
    /// 0 sentence, 1 link, 2 image: put a real item on the pasteboard (the app's own watcher records it like any other copy).
    func copySample(_ k: Int) {
        let pb = NSPasteboard.general; pb.clearContents()
        switch k { case 0: pb.setString(OnbModel.sampleText, forType: .string); case 1: pb.setString(OnbModel.sampleLink, forType: .string); default: pb.writeObjects([OnbModel.sampleImage]) }
    }
}

// MARK: window

final class OnbWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OnbController: NSObject, NSWindowDelegate {
    let window: OnbWindow, model = OnbModel()
    private var monitor: Any?, observers: [NSObjectProtocol] = []
    private var closing = false

    override init() {
        window = OnbWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520), styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false; window.delegate = self; window.title = "Welcome to Pastry"; window.level = .normal
        let (glass, content) = Glass.surface(radius: 38, tint: dyn(NSColor.white.withAlphaComponent(0.35), NSColor.black.withAlphaComponent(0.3)), material: .hudWindow)
        let host = NSHostingView(rootView: OnbRoot(model: model))
        host.frame = content.bounds; host.autoresizingMask = [.width, .height]; content.addSubview(host)
        glass.frame = NSRect(x: 0, y: 0, width: 760, height: 520); window.contentView = glass
        model.close = { [weak self] in self?.dismiss() }
    }

    func present() {
        window.center(); window.alphaValue = 0
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { c in c.duration = 0.5; c.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1); window.animator().alphaValue = 1 }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in self?.key(e) ?? e }
        let nc = NotificationCenter.default
        for n in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            observers.append(nc.addObserver(forName: n, object: window, queue: .main) { [weak self] _ in self?.syncActive() })
        }
        syncActive()
    }
    private func syncActive() { model.active = window.isVisible && window.occlusionState.contains(.visible) && !window.isMiniaturized }

    private func key(_ e: NSEvent) -> NSEvent? {
        guard e.window === window, e.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return e }
        if e.modifierFlags.contains(.shift) {   // ⇧→ / ⇧← drive the suggestions demo
            guard model.step == .suggest, e.keyCode == 124 || e.keyCode == 123 else { return e }
            model.jump(e.keyCode == 124); return nil
        }
        switch e.keyCode {
        case 124, 36, 76: model.next()    // → ↩ (enter)
        case 123: model.back()            // ←
        case 53: dismiss()                // esc
        default: return e
        }
        return nil
    }

    /// Fade out, then release everything.
    func dismiss() {
        guard !closing else { return }; closing = true
        Prefs.d.set(true, forKey: "onboardingDone"); Prefs.d.removeObject(forKey: "onboardingResume")   // closing (esc, x, Skip, Start) counts as done; quitting the app mid-tour does not
        model.teardown()
        NSAnimationContext.runAnimationGroup({ c in c.duration = 0.28; window.animator().alphaValue = 0 }, completionHandler: { [weak self] in self?.window.close() })
    }
    func windowWillClose(_ n: Notification) {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers = []; model.teardown(); window.contentView = nil
        Onboarding.controller = nil
    }
}
