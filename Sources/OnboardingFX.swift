// Pastry onboarding: reusable motion + glass pieces (animated mesh background, confetti, tilt, glass modifiers, keycaps).
import SwiftUI
import AppKit

var onbReduce: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
/// Springs everywhere; with Reduce Motion they become short crossfade-friendly eases.
func onbSpring(_ response: Double = 0.6, _ damping: Double = 0.75) -> Animation { onbReduce ? .easeInOut(duration: 0.2) : .spring(response: response * 1.3, dampingFraction: min(0.92, damping + 0.12)) }
/// The one accent: the donut-frosting pink from the app icon.
let brand = Color(red: 0.91, green: 0.38, blue: 0.56)
func unit(_ i: Int, _ k: Double) -> Double { let x = sin(Double(i) * 12.9898 + k * 78.233) * 43758.5453; return x - x.rounded(.down) }

// MARK: glass

extension View {
    /// Liquid Glass on macOS 26+, a material with a hairline otherwise.
    @ViewBuilder func pGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if Glass.native, #available(macOS 26, *) {
            self.glassEffect(interactive ? (tint.map { Glass_.regular.tint($0).interactive() } ?? Glass_.regular.interactive()) : (tint.map { Glass_.regular.tint($0) } ?? Glass_.regular), in: shape)
        } else {
            self.background(shape.fill(.regularMaterial)).background(shape.fill(tint?.opacity(0.18) ?? .clear))
                .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        }
    }
    @ViewBuilder func pButton(prominent: Bool = false) -> some View {
        if Glass.native, #available(macOS 26, *) { if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) } }
        else if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
    }
    /// Groups nearby glass so shapes blend and morph (macOS 26); a plain container before.
    @ViewBuilder func pGlassGroup(_ spacing: CGFloat = 24) -> some View {
        if Glass.native, #available(macOS 26, *) { GlassEffectContainer(spacing: spacing) { self } } else { self }
    }
    func tilt(_ amount: Double = 14) -> some View { modifier(Tilt(amount: amount)) }
}
@available(macOS 26, *) typealias Glass_ = SwiftUI.Glass

/// Mouse-following 3D tilt with a specular highlight.
/// (@State is a macro whose plugin is missing from the Command Line Tools, so local view state lives in tiny observable boxes.)
final class TiltState: ObservableObject { @Published var p = CGSize.zero; @Published var hovering = false }
struct Tilt: ViewModifier {
    var amount: Double
    @StateObject private var st = TiltState()
    func body(content: Content) -> some View {
        content
            .overlay(RadialGradient(colors: [.white.opacity(st.hovering ? 0.28 : 0), .clear], center: UnitPoint(x: st.p.width + 0.5, y: st.p.height + 0.5), startRadius: 0, endRadius: 120).allowsHitTesting(false).blendMode(.plusLighter))
            .rotation3DEffect(.degrees(-st.p.height * amount), axis: (1, 0, 0), perspective: 0.5)
            .rotation3DEffect(.degrees(st.p.width * amount), axis: (0, 1, 0), perspective: 0.5)
            .scaleEffect(st.hovering ? 1.04 : 1)
            .overlay(GeometryReader { g in
                Color.clear.contentShape(Rectangle()).onContinuousHover { ph in
                    guard !onbReduce else { return }
                    switch ph {
                    case .active(let l): withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) { st.hovering = true; st.p = CGSize(width: l.x / g.size.width - 0.5, height: l.y / g.size.height - 0.5) }
                    case .ended: withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { st.hovering = false; st.p = .zero }
                    }
                }
            })
    }
}

// MARK: background

/// Restrained brand backdrop: a near-neutral base that follows light/dark, two huge blurred glows (strawberry frosting, faint caramel)
/// drifting very slowly, fine grain against banding, a soft vignette. The clock stops when hidden or with Reduce Motion.
struct OnbBackground: View {
    var active: Bool
    var step: Int
    @Environment(\.colorScheme) private var scheme
    static let grain: NSImage = {
        let n = 128, rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<n { for x in 0..<n { let v = CGFloat(unit(x * n + y, 9)); rep.setColor(NSColor(white: v, alpha: 1), atX: x, y: y) } }
        let i = NSImage(size: NSSize(width: n, height: n)); i.addRepresentation(rep); return i
    }()
    var body: some View {
        let dark = scheme == .dark
        ZStack {
            (dark ? Color(red: 0.085, green: 0.082, blue: 0.09) : Color(red: 0.972, green: 0.962, blue: 0.952))
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active || onbReduce)) { tl in
                let t = onbReduce ? 0 : tl.date.timeIntervalSinceReferenceDate, k = Double(step) * 0.35
                ZStack {
                    Circle().fill(brand.opacity(dark ? 0.12 : 0.11)).frame(width: 420, height: 420)
                        .offset(x: -170 + 60 * sin(t * 0.05 + k) + CGFloat(step) * 14, y: -150 + 40 * cos(t * 0.04))
                    Circle().fill(Color(red: 0.93, green: 0.74, blue: 0.52).opacity(dark ? 0.05 : 0.10)).frame(width: 360, height: 360)
                        .offset(x: 200 + 50 * cos(t * 0.045), y: 170 + 40 * sin(t * 0.05 + k))
                }.blur(radius: 90)
            }
            .animation(.easeInOut(duration: 1.6), value: step)
            Image(nsImage: OnbBackground.grain).resizable(resizingMode: .tile).opacity(dark ? 0.035 : 0.03).blendMode(.overlay)
            RadialGradient(colors: [.clear, .black.opacity(dark ? 0.35 : 0.07)], center: .center, startRadius: 220, endRadius: 520)
        }
        .opacity(0.9).allowsHitTesting(false)
    }
}

// MARK: confetti

/// A soft ripple plus a few brand-coloured motes, computed from the time since `start`; the clock pauses when idle.
struct Confetti: View {
    var start: Date?
    var active: Bool
    private let life = 2.4
    var body: some View {
        TimelineView(.animation(paused: start == nil || !active)) { tl in
            Canvas { ctx, size in
                guard let s = start else { return }
                let t = tl.date.timeIntervalSince(s)
                guard t >= 0, t < life else { return }
                let o = CGPoint(x: size.width / 2, y: size.height * 0.5)
                let p = 1 - pow(1 - min(1, t / 1.4), 3)
                let r = 40 + 330 * p
                ctx.stroke(Path(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2)), with: .color(Color.primary.opacity(0.16 * (1 - p))), lineWidth: 2 + 10 * (1 - p))
                let palette: [Color] = [.white, Color(red: 0.95, green: 0.82, blue: 0.66), Color.primary.opacity(0.5)]
                for i in 0..<(onbReduce ? 0 : 16) {
                    let a = unit(i, 1) * .pi * 2, v = 90 + unit(i, 2) * 230
                    let x = o.x + cos(a) * v * p * 1.2, y = o.y + sin(a) * v * p * 1.2 + 26 * t * t
                    let sz = 3 + unit(i, 3) * 4, alpha = min(1, (life - t) / 0.9)
                    var c = ctx; c.opacity = alpha * 0.9
                    c.fill(Path(ellipseIn: CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)), with: .color(palette[i % palette.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: small parts

struct Keycap: View {
    var label: String, pressed: Double   // 0...1
    var body: some View {
        Text(label).font(.system(size: 26, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
            .frame(minWidth: 58, minHeight: 58).padding(.horizontal, label.count > 2 ? 10 : 0)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.background.opacity(0.8)))
            .pGlass(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.22 * (1 - pressed)), radius: 6, y: 5 * (1 - pressed))
            .offset(y: 5 * pressed).scaleEffect(1 - 0.04 * pressed)
    }
}

struct ProgressDots: View {
    var step: Int, count: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule().fill(i == step ? Color.primary.opacity(0.8) : Color.primary.opacity(i < step ? 0.4 : 0.16))
                    .frame(width: i == step ? 26 : 7, height: 7)
            }
        }
        .animation(onbSpring(0.5, 0.62), value: step)
        .accessibilityLabel("Step \(step + 1) of \(count)")
    }
}

/// One clipboard card: tinted header, content, source app.
struct ClipCard: View {
    var kind: String, title: String, meta: String, app: String, image: NSImage?
    var size = CGSize(width: 150, height: 176)
    var tint: Color { ["text": Color(red: 0.36, green: 0.5, blue: 0.82), "link": Color(red: 0.3, green: 0.62, blue: 0.66), "image": Color(red: 0.62, green: 0.46, blue: 0.78), "file": Color(red: 0.85, green: 0.58, blue: 0.36)][kind] ?? .blue }
    var symbol: String { ["text": "text.alignleft", "link": "link", "image": "photo", "file": "doc.fill"][kind] ?? "doc" }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                if size.width > 100 { Text(kind.capitalized).font(.system(size: 11, weight: .bold)) }; Spacer()
            }.foregroundStyle(.white).padding(.horizontal, 10).frame(height: 28).background(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
            Group {
                if let image { Image(nsImage: image).resizable().scaledToFill().frame(width: size.width, height: size.height - 28 - 22).clipped() }
                else { Text(title).font(.system(size: 12.5, weight: .regular, design: kind == "link" ? .default : .rounded)).foregroundStyle(kind == "link" ? Color.blue : .primary)
                    .lineLimit(5).multilineTextAlignment(.leading).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10) }
            }
            Text(app.isEmpty ? meta : "\(app) · \(meta)").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                .padding(.horizontal, 10).frame(height: 22, alignment: .center).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.background.opacity(0.92)))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.14), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

/// Card flies in from the left with a spin and a squash.
struct FlyIn: ViewModifier {
    var on: Bool
    func body(content: Content) -> some View {
        content.offset(x: on ? -260 : 0, y: on ? -50 : 0).scaleEffect(on ? 0.35 : 1).rotationEffect(.degrees(on ? -24 : 0)).opacity(on ? 0 : 1)
    }
}
struct SlideFade: ViewModifier {
    var on: Bool, x: CGFloat = 0, blur: CGFloat = 10, scale: CGFloat = 1
    func body(content: Content) -> some View {
        content.offset(x: on ? x : 0).scaleEffect(on ? scale : 1).blur(radius: on ? blur : 0).opacity(on ? 0 : 1)
    }
}
