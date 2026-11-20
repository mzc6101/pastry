// Pastry onboarding: the SwiftUI screens.
import SwiftUI
import AppKit

private let copyText: [OnbModel.Step: (String, String)] = [
    .welcome: ("Your clipboard, remembered", "Everything you copy, one shortcut away. Pastry keeps the history so you never lose a link again."),
    .copy: ("Copy something now", "Select the highlighted sentence and press ⌘C. Pastry catches it the moment it lands."),
    .shelf: ("Press ", "That's the shelf. Return pastes, Tab flips to Pinned, and Esc gets you out."),
    .suggest: ("Pastry anticipates your paste", "Open the shelf in any app. Three suggestions appear on the right, picked for where you are."),
    .access: ("One permission, then paste", "Pastry needs Accessibility to paste into other apps for you. Grant it once; you can revoke it anytime."),
    .finish: ("Start using Pastry", "Pastry lives quietly in the background. Turn on launch at login so it's ready after every restart."),
]

struct OnbRoot: View {
    @ObservedObject var model: OnbModel
    var body: some View {
        let r = onbReduce
        ZStack {
            OnbBackground(active: model.active, step: model.step.rawValue)
            VStack(spacing: 0) {
                ZStack {
                    screen.id(model.step)
                        .transition(.asymmetric(insertion: .modifier(active: SlideFade(on: true, x: r ? 0 : (model.forward ? 80 : -80), blur: r ? 0 : 10), identity: SlideFade(on: false)),
                                                removal: .modifier(active: SlideFade(on: true, blur: r ? 0 : 12, scale: r ? 1 : 0.94), identity: SlideFade(on: false))))
                }
                .animation(onbSpring(0.7, 0.85), value: model.step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
            topBar
            Confetti(start: model.burst, active: model.active)
        }
        .focusEffectDisabled()
        .frame(width: 760, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
    }

    @ViewBuilder var screen: some View {
        let (t, s) = copyText[model.step]!
        switch model.step {
        case .welcome: Layout(title: t, subtitle: s, stage: WelcomeStage(), extra: EmptyView())
        case .copy: Layout(title: t, subtitle: s, stage: CopyStage(model: model), extra: EmptyView())
        case .shelf:
            Layout(title: model.shelfOpened ? "Got it" : t + model.hotkey, subtitle: model.shelfOpened ? "That's the shelf: every copy, newest first. Return pastes, Tab flips to Pinned, Esc closes it." : s, stage: ShelfStage(model: model),
                   extra: ShelfHint(model: model))
        case .suggest: Layout(title: t, subtitle: s, stage: SuggestStage(model: model), extra: Picked(model: model))
        case .access: Layout(title: t, subtitle: s, stage: AccessStage(model: model), extra: AccessActions(model: model))
        case .finish: Layout(title: t, subtitle: s, stage: FinishStage(model: model), extra: FinishToggle(model: model), stageHeight: 200)
        }
    }

    var topBar: some View {
        VStack {
            HStack {
                Button { model.close() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 18, height: 18) }
                    .pButton().buttonBorderShape(.circle).help("Close (esc)").accessibilityLabel("Close")
                Spacer()
                if model.step != .finish { Button("Skip tour") { model.close() }.buttonStyle(.plain).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 22).padding(.top, 20)
            Spacer()
        }
    }

    var primary: (title: String, prominent: Bool) {
        switch model.step {
        case .welcome: return ("Get started", true)
        case .copy: return model.clips.isEmpty ? ("Skip", false) : ("Next", true)
        case .shelf: return model.shelfOpened ? ("Next", true) : ("Skip", false)
        case .suggest: return ("Next", true)
        case .access: return model.ax == .missing ? ("Skip for now", false) : ("Next", true)
        case .finish: return ("Start using Pastry", true)
        }
    }
    var bottomBar: some View {
        HStack {
            Button { model.back() } label: { Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold)).frame(width: 20, height: 20) }
                .pButton().buttonBorderShape(.circle).opacity(model.step == .welcome ? 0 : 1).disabled(model.step == .welcome).help("Back (←)").accessibilityLabel("Back")
                .frame(width: 150, alignment: .leading)
            Spacer()
            ProgressDots(step: model.step.rawValue, count: model.count)
            Spacer()
            Button { model.next() } label: { Text(primary.title).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 10).frame(minHeight: 22) }
                .pButton(prominent: primary.prominent).tint(primary.prominent ? brand : nil).buttonBorderShape(.capsule).help("↩")
                .frame(minWidth: 150, alignment: .trailing)
        }
        .padding(.horizontal, 28).padding(.bottom, 26).padding(.top, 6)
    }
}

/// Stage on top, title + subtitle under it, optional extras below.
struct Layout<Stage: View, Extra: View>: View {
    var title: String, subtitle: String, stage: Stage, extra: Extra
    var stageHeight: CGFloat = 250
    var body: some View {
        VStack(spacing: 8) {
            stage.frame(height: stageHeight).padding(.top, 50)
            Text(title).font(.system(size: 31, weight: .semibold)).tracking(-0.7).contentTransition(.interpolate)
            Text(subtitle).font(.system(size: 15)).tracking(-0.1).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(2)
                .frame(maxWidth: 520).fixedSize(horizontal: false, vertical: true)
            extra.padding(.top, 6)
            Spacer(minLength: 0)
        }
    }
}

// MARK: 1 Welcome: a glass blob melts into the shelf, cards spring up out of it

final class WelcomeState: ObservableObject { @Published var open = false; @Published var shown = 0 }
struct WelcomeStage: View {
    @StateObject private var st = WelcomeState()
    private let samples: [(String, String, String, String)] = [("text", "Meeting notes: ship onboarding Friday", "Notes", "42 chars"), ("link", "apple.com/macos", "Safari", "Link"),
                                                               ("text", "swift build -c release", "Ghostty", "22 chars"), ("text", "Order #48213 confirmed", "Mail", "22 chars")]
    var body: some View {
        ZStack {
            if !st.open { Goo().transition(.opacity) }
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    ClipCard(kind: samples[i].0, title: samples[i].1, meta: samples[i].3, app: samples[i].2, image: nil, size: CGSize(width: 108, height: 134)).tilt(10)
                        .offset(x: CGFloat(i - 2) * 120 + 98, y: st.shown > i ? 0 : 110).scaleEffect(st.shown > i ? 1 : 0.5).opacity(st.shown > i ? 1 : 0)
                        .animation(onbSpring(0.6, 0.62), value: st.shown)
                }
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: st.open ? 64 : 76, height: st.open ? 64 : 76)
                    .offset(x: st.open ? -268 : 0, y: 0).shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .frame(width: st.open ? 650 : 100, height: st.open ? 176 : 100)
            .pGlass(RoundedRectangle(cornerRadius: st.open ? 36 : 50, style: .continuous))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(onbSpring(0.9, 0.7)) { st.open = true }
                for i in 0..<4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + 0.08 * Double(i)) { st.shown = i + 1 } }
            }
        }
    }
}

/// Metaball droplets orbiting the blob (alpha-threshold on a blurred layer makes them merge).
struct Goo: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: onbReduce)) { tl in
            Canvas { ctx, size in
                let t = onbReduce ? 0 : tl.date.timeIntervalSinceReferenceDate, c = CGPoint(x: size.width / 2, y: size.height / 2)
                ctx.addFilter(.alphaThreshold(min: 0.5, color: .white.opacity(0.55)))
                ctx.addFilter(.blur(radius: 10))
                ctx.drawLayer { l in
                    l.fill(Path(ellipseIn: CGRect(x: c.x - 52, y: c.y - 52, width: 104, height: 104)), with: .color(.black))
                    for i in 0..<4 {
                        let a = t * (0.9 + Double(i) * 0.25) + Double(i) * 1.7, d = 62 + 14 * sin(t * 1.3 + Double(i)), r = 13 + 5 * sin(t * 1.7 + Double(i) * 2)
                        l.fill(Path(ellipseIn: CGRect(x: c.x + cos(a) * d - r, y: c.y + sin(a) * d - r, width: r * 2, height: r * 2)), with: .color(.black))
                    }
                }
            }
        }.frame(width: 260, height: 260)
    }
}

// MARK: 2 Copy something

struct CopyStage: View {
    @ObservedObject var model: OnbModel
    private let panel = CGSize(width: 330, height: 232), card = CGSize(width: 120, height: 144), step: CGFloat = 52
    var body: some View {
        HStack(spacing: 24) { sources; shelf }
    }
    var sources: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(0) { Text(OnbModel.sampleText).font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                .padding(.horizontal, 6).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.3))) }
            row(1) { Text("apple.com/macos").font(.system(size: 13)).foregroundStyle(.blue).underline().textSelection(.enabled) }
            row(2) { Image(nsImage: OnbModel.sampleImage).resizable().scaledToFill().frame(width: 64, height: 40).clipShape(RoundedRectangle(cornerRadius: 8)) }
        }
        .padding(24).frame(width: panel.width, height: panel.height).pGlass(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
    private func row<C: View>(_ k: Int, @ViewBuilder _ c: () -> C) -> some View {
        HStack { c(); Spacer(minLength: 6)
            Button { model.copySample(k) } label: { Label("Copy", systemImage: "doc.on.doc").font(.system(size: 11.5, weight: .semibold)) }.pButton().buttonBorderShape(.capsule).controlSize(.small) }
            .frame(height: 48)
    }
    var shelf: some View {
        let n = model.clips.count, span = card.width + step * CGFloat(max(0, n - 1)), x0 = (panel.width - 48 - span) / 2
        return VStack(spacing: 16) {
            Badge(n: n)
            ZStack(alignment: .leading) {
                if n == 0 {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .frame(width: card.width, height: card.height)
                        .overlay(VStack(spacing: 8) { Image(systemName: "arrow.down.doc").font(.system(size: 24)).symbolEffect(.pulse, options: .repeating); Text("Waiting for\nyour copy…").font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center) }.foregroundStyle(.secondary))
                        .offset(x: (panel.width - 48 - card.width) / 2)
                }
                ForEach(Array(model.clips.enumerated()), id: \.element.id) { i, c in
                    ClipCard(kind: c.kind, title: c.title, meta: c.meta, app: c.app, image: c.image, size: card).tilt(10)
                        .offset(x: x0 + step * CGFloat(i)).zIndex(Double(n - i))
                        .transition(.modifier(active: FlyIn(on: !onbReduce), identity: FlyIn(on: false)))
                }
            }
            .frame(width: panel.width - 48, height: card.height, alignment: .leading)
        }
        .padding(24).frame(width: panel.width, height: panel.height).pGlass(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

struct Badge: View {
    var n: Int
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.2), lineWidth: 2)
                Circle().trim(from: 0, to: n > 0 ? 1 : 0).stroke(brand, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundStyle(brand).opacity(n > 0 ? 1 : 0).scaleEffect(n > 0 ? 1 : 0.3)
            }.frame(width: 18, height: 18)
            Text("\(n) copied").font(.system(size: 12, weight: .semibold)).monospacedDigit().contentTransition(.numericText(value: Double(n)))
        }
        .padding(.horizontal, 12).padding(.vertical, 6).pGlass(Capsule(), tint: nil)
        .animation(onbSpring(0.6, 0.6), value: n)
    }
}

// MARK: 3 Open the shelf

struct ShelfStage: View {
    @ObservedObject var model: OnbModel
    @StateObject private var cs = FlagBox()
    var caps: [String] {
        let s = Array(model.hotkey), mods = s.prefix { "⌃⌥⇧⌘".contains($0) }
        return mods.map { String($0) } + [String(s.dropFirst(mods.count))]
    }
    var body: some View {
        let open = model.shelfOpened
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.active || open || onbReduce)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate, cyc = t.truncatingRemainder(dividingBy: 2.6)
                HStack(spacing: 10) {
                    ForEach(Array(caps.enumerated()), id: \.offset) { i, c in
                        let d = cyc - 0.25 * Double(i), p = d < 0 ? 0 : d < 0.12 ? d / 0.12 : max(0, 1 - (d - 0.12) / 0.3)
                        Keycap(label: c, pressed: p)
                    }
                }
                .scaleEffect(open ? 0.6 : 1).opacity(open ? 0 : 1).blur(radius: open ? 8 : 0)
            }
            if open {
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { i in
                        card(i).offset(x: cs.n > i ? 0 : -160, y: cs.n > i ? 0 : 20).scaleEffect(cs.n > i ? 1 : 0.6, anchor: .leading).opacity(cs.n > i ? 1 : 0)
                            .animation(onbSpring(0.6, 0.58), value: cs.n)
                    }
                }
                .transition(.identity)
            }
        }
        .frame(width: open ? 650 : 300, height: open ? 196 : 112)
        .pGlass(RoundedRectangle(cornerRadius: open ? 36 : 40, style: .continuous), tint: nil)
        .animation(onbSpring(0.9, 0.68), value: open)
        .onChange(of: open) { _, o in if o { for i in 0..<4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + 0.09 * Double(i)) { cs.n = i + 1 } } } }
    }
    @ViewBuilder func card(_ i: Int) -> some View {
        let sz = CGSize(width: 130, height: 160)
        if i == 0 {
            if let c = model.clips.first { ClipCard(kind: c.kind, title: c.title, meta: c.meta, app: c.app, image: c.image, size: sz).tilt(10) }
            else { ClipCard(kind: "text", title: OnbModel.sampleText, meta: "44 characters", app: "Pastry", image: nil, size: sz).tilt(10) }
        } else {
            let s = [("link", "apple.com/macos", "Safari", "Link"), ("text", "swift build -c release", "Ghostty", "22 chars"), ("text", "Order #48213 confirmed", "Mail", "22 chars")][i - 1]
            ClipCard(kind: s.0, title: s.1, meta: s.3, app: s.2, image: nil, size: sz).tilt(10)
        }
    }
}
struct ShelfHint: View {
    @ObservedObject var model: OnbModel
    var body: some View {
        if model.hint && !model.shelfOpened {
            Button("Open the shelf for me") { model.showShelfForMe() }.pButton().buttonBorderShape(.capsule).transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: 4 Smart suggestions

struct Sug: Identifiable { let id = UUID(); var symbol: String, title: String, sub: String, color: Color }

func suggestions(for bundle: String) -> [Sug] {
    switch Suggest.category(bundle) {
    case .browser: return [Sug(symbol: "link", title: "Link", sub: "apple.com/macos", color: brand), Sug(symbol: "text.quote", title: "Quote", sub: "“Simple is hard.”", color: brand), Sug(symbol: "doc.plaintext", title: "Plain text", sub: "Pasted without styling", color: brand)]
    case .code: return [Sug(symbol: "curlybraces", title: "Snippet", sub: "func fetch() async", color: brand), Sug(symbol: "exclamationmark.triangle", title: "Error", sub: "Cannot find 'x' in scope", color: brand), Sug(symbol: "terminal", title: "Command", sub: "swift build -c release", color: brand)]
    case .terminal: return [Sug(symbol: "terminal", title: "Command", sub: "git rebase -i HEAD~3", color: brand), Sug(symbol: "link", title: "Repo URL", sub: "github.com/you/app", color: brand), Sug(symbol: "key", title: "Path", sub: "~/Code/paste-re", color: brand)]
    case .mail, .chat: return [Sug(symbol: "envelope", title: "Address", sub: "jane@acme.com", color: brand), Sug(symbol: "text.bubble", title: "Reply", sub: "Sounds good, I'll take a look", color: brand), Sug(symbol: "link", title: "Link", sub: "Meeting notes", color: brand)]
    case .design: return [Sug(symbol: "photo", title: "Screenshot", sub: "1440 × 900", color: brand), Sug(symbol: "paintpalette", title: "Color", sub: "#FF7A59", color: brand), Sug(symbol: "textformat", title: "Heading", sub: "Hello, world", color: brand)]
    default: return [Sug(symbol: "doc.text", title: "Notes", sub: "Meeting notes: Friday", color: brand), Sug(symbol: "link", title: "Link", sub: "apple.com/macos", color: brand), Sug(symbol: "photo", title: "Image", sub: "Screenshot 14.02", color: brand)]
    }
}

final class FlagBox: ObservableObject { @Published var n = 0; @Published var on = false }
struct SuggestStage: View {
    @ObservedObject var model: OnbModel
    @StateObject private var st = FlagBox()
    @Namespace private var ns
    private var ring: some View { RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Color.primary.opacity(0.8), lineWidth: 2.5).matchedGeometryEffect(id: "ring", in: ns) }
    var body: some View {
        let tiles = suggestions(for: model.front.bundle)
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        ClipCard(kind: ["text", "link", "text"][i], title: ["Draft intro", "apple.com", "Order #48213"][i], meta: "", app: "", image: nil, size: CGSize(width: 74, height: 128)).opacity(0.55).scaleEffect(0.96)
                            .overlay { if i == 0 && !model.jumped { ring } }
                    }
                }
                Capsule().fill(Color.primary.opacity(0.18)).frame(width: 1.5, height: 118)
                HStack(spacing: 10) {
                    ForEach(Array(tiles.enumerated()), id: \.element.id) { i, t in
                        Tile3(s: t).offset(x: st.on ? 0 : 150 - CGFloat(i) * 30, y: st.on ? 0 : -110).scaleEffect(st.on ? 1 : 0.1).opacity(st.on ? 1 : 0)
                            .animation(onbSpring(0.65, 0.6).delay(Double(st.on ? i : 2 - i) * 0.08), value: st.on)
                            .overlay { if i == 0 && model.jumped && st.on { ring } }
                    }
                }
            }
            .padding(.horizontal, 20).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 14)
            Button { st.on.toggle() } label: { Image(systemName: st.on ? "sparkles" : "sparkle").font(.system(size: 15, weight: .semibold)).frame(width: 22, height: 22).symbolEffect(.bounce, value: st.on) }
                .pButton().buttonBorderShape(.circle).padding(12).help("Turn suggestions on or off")
        }
        .frame(width: 690, height: 196).pGlass(RoundedRectangle(cornerRadius: 36, style: .continuous), tint: nil)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { st.on = true } }
    }
}
struct Tile3: View {
    var s: Sug
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: s.symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(nsColor: .windowBackgroundColor)).frame(width: 32, height: 32).background(Circle().fill(Color.primary.opacity(0.78)))
            Spacer(minLength: 0)
            Text(s.title).font(.system(size: 13, weight: .bold, design: .rounded))
            Text(s.sub).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
        }
        .padding(12).frame(width: 118, height: 134, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.background.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LinearGradient(colors: [Color.primary.opacity(0.28), Color.primary.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5).tilt(14)
    }
}
struct MiniKey: View {
    var label: String
    var body: some View {
        Text(label).font(.system(size: 13, weight: .semibold, design: .rounded)).frame(minWidth: 26, minHeight: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.primary.opacity(0.18), lineWidth: 0.5))
    }
}
/// "Picked for <app>" plus the ⇧→ hint; pressing ⇧→ (or the auto-demo) moves the selection ring into the suggestions.
struct Picked: View {
    @ObservedObject var model: OnbModel
    var body: some View {
        HStack(spacing: 10) {
            if let i = model.front.icon { Image(nsImage: i).resizable().frame(width: 20, height: 20) }
            Text("Picked for \(model.front.name)").font(.system(size: 13, weight: .semibold))
            Capsule().fill(Color.primary.opacity(0.2)).frame(width: 1, height: 16)
            HStack(spacing: 4) { MiniKey(label: "⇧"); MiniKey(label: model.jumped ? "←" : "→") }
            Text(model.jumped ? "Press ⇧← to go back to history" : "Press ⇧→ to jump to suggestions").font(.system(size: 12.5)).foregroundStyle(.secondary).contentTransition(.interpolate)
        }
        .padding(.horizontal, 14).padding(.vertical, 7).pGlass(Capsule())
        .animation(onbSpring(0.5, 0.8), value: model.jumped)
    }
}

// MARK: 5 Accessibility

struct AccessStage: View {
    @ObservedObject var model: OnbModel
    var granted: Bool { model.axGranted || model.ax != .missing }
    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.active || granted || onbReduce)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        let p = (t / 2 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                        Circle().stroke(Color.primary.opacity(0.18 * (1 - p)), lineWidth: 2).frame(width: 140 + 150 * p, height: 140 + 150 * p)
                    }
                }.opacity(granted ? 0 : 1)
            }
            Circle().fill(granted ? Color.primary.opacity(0.08) : .clear).frame(width: granted ? 170 : 40).blur(radius: 18).animation(onbSpring(0.7, 0.7), value: granted)
            ZStack {
                Image(systemName: granted ? "lock.open.fill" : "lock.fill").font(.system(size: 54, weight: .medium))
                    .foregroundStyle(Color.primary).contentTransition(.symbolEffect(.replace)).symbolEffect(.bounce, value: granted)
            }
            .frame(width: 140, height: 140).pGlass(Circle(), tint: nil)
            if granted { Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(brand, .white).background(Circle().fill(.white).padding(4)).offset(x: 52, y: 50).transition(.scale(scale: 0.1).combined(with: .opacity)) }
        }
        .animation(onbSpring(0.6, 0.6), value: granted)
    }
}
struct AccessActions: View {
    @ObservedObject var model: OnbModel
    var body: some View {
        VStack(spacing: 8) {
            switch model.ax {
            case .missing:
                Button { model.openAccessibility() } label: { Label("Open System Settings", systemImage: "gearshape").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 6) }.pButton(prominent: true).buttonBorderShape(.capsule).controlSize(.large)
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Waiting for permission. Skipping is fine: copying and browsing still work, pasting waits.").font(.system(size: 12)).foregroundStyle(.secondary) }
            case .stale:
                Button { model.relaunch() } label: { Label("Relaunch Pastry", systemImage: "arrow.clockwise").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 6) }.pButton(prominent: true).buttonBorderShape(.capsule).controlSize(.large)
                Text("Granted. Relaunch once so pasting can start; this tour resumes here.").font(.system(size: 12)).foregroundStyle(.secondary)
            case .trusted:
                Text(model.axGranted ? "Granted. Pasting is ready." : "Already granted. Pasting is ready.").font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
            }
        }
        .animation(onbSpring(), value: model.ax)
    }
}

// MARK: 6 Finish

struct FinishStage: View {
    @ObservedObject var model: OnbModel
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.active || onbReduce)) { tl in
            let t = onbReduce ? 0 : tl.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let a = t * 0.35 + Double(i) * 1.2566, r = 100.0 + 8 * sin(t + Double(i))
                    Image(systemName: ["sparkle", "doc.on.clipboard", "link", "photo", "pin.fill"][i]).font(.system(size: 15, weight: .semibold)).foregroundStyle(i == 0 ? Color.white : Color.primary.opacity(0.7))
                        .frame(width: 38, height: 38).pGlass(Circle()).offset(x: cos(a) * r * 1.7, y: sin(a) * r * 0.85)
                }
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128).shadow(color: .black.opacity(0.3), radius: 14, y: 8).offset(y: 3 * sin(t * 1.5))
            }
        }
    }
}
struct FinishToggle: View {
    @ObservedObject var model: OnbModel
    var body: some View {
        VStack(spacing: 4) {
            Toggle(isOn: Binding(get: { model.loginOn }, set: { model.setLogin($0) })) { Text("Launch Pastry at login").font(.system(size: 14, weight: .semibold)) }
                .toggleStyle(.switch).tint(brand).padding(.horizontal, 18).padding(.vertical, 10).frame(width: 330).pGlass(Capsule())
            Text("Change anytime in Settings > General.").font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
    }
}
