// Pastry: "Suggested for <App>" tiles. A heuristic ranker answers instantly; the on-device model (FoundationModels) may refine it
// once per (frontmost app, history version) when the shelf opens. One request in flight at most, cancelled when the shelf closes.
import AppKit
import ApplicationServices
#if canImport(FoundationModels)
import FoundationModels
#endif

enum Suggest {
    enum Source: String { case model = "on-device model", heuristic = "quick ranking" }
    static let count = 3
    private static var cache: [String: ([Int64], Source)] = [:]
    private static var inflight: Task<Void, Never>?

    enum Cat { case mail, code, terminal, chat, browser, finder, design, writing, other }
    static func category(_ bundle: String, title: String = "") -> Cat {
        let b = bundle.lowercased(), t = title.lowercased()
        if ["com.apple.finder"].contains(b) { return .finder }
        if b.contains("terminal") || b.contains("ghostty") || b.contains("iterm") || b.contains("warp") || b.contains("kitty") || b.contains("alacritty") { return .terminal }
        if b.contains("xcode") || b.contains("vscode") || b.contains("cursor") || b.contains("jetbrains") || b.contains("sublime") || b.contains("zed") || b.contains("nova") { return .code }
        if b.contains("mail") || b.contains("outlook") || b.contains("spark") || b.contains("superhuman") || b.contains("mimestream") { return .mail }
        if b.contains("mobilesms") || b.contains("slack") || b.contains("discord") || b.contains("whatsapp") || b.contains("telegram") || b.contains("teams") || b.contains("beeper") || b.contains("signal") { return .chat }
        if b.contains("figma") || b.contains("adobe") || b.contains("sketch") || b.contains("pixelmator") || b.contains("preview") || b.contains("affinity") || b.contains("shottr") || b.contains("canva") { return .design }
        if b.contains("safari") || b.contains("chrome") || b.contains("firefox") || b.contains("thebrowser") || b.contains("brave") || b.contains("edgemac") || b.contains("ardia") || b.contains("arc") {
            if t.contains("gmail") || t.contains("outlook") || t.contains("inbox") || t.contains("compose") || t.contains("yahoo mail") { return .mail }
            if t.contains("slack") || t.contains("whatsapp") || t.contains("messenger") || t.contains("discord") { return .chat }
            if t.contains("github") || t.contains("stack overflow") || t.contains("codepen") { return .code }
            if t.contains("figma") || t.contains("canva") { return .design }
            return .browser
        }
        if b.contains("textedit") || b.contains("notes") || b.contains("pages") || b.contains("word") || b.contains("notion") || b.contains("obsidian") || b.contains("bear") || b.contains("keynote") { return .writing }
        return .other
    }
    static func isBrowser(_ bundle: String) -> Bool { category(bundle) == .browser }

    // MARK: heuristic ranker (pure, microseconds)
    private static let cmds: Set<String> = ["git", "cd", "ls", "npm", "npx", "brew", "docker", "ssh", "curl", "swift", "swiftc", "make", "sudo", "python", "python3", "pip", "kubectl", "cargo", "yarn", "pnpm", "cat", "grep", "open", "kill", "chmod", "node", "xcodebuild", "defaults"]
    private static let codeMarks = ["{", "};", "func ", "def ", "import ", "=>", "</", "();", "#include", "const ", "let ", "var ", "class ", "return "]
    private static let greetings = ["hi ", "hi,", "hello", "dear ", "hey ", "thanks", "thank you", "best", "regards", "sincerely", "cheers", "good morning", "i hope"]
    static func score(_ r: Store.Row, rank: Int, cat: Cat) -> Double {
        let text = (r.preview.isEmpty ? r.title : r.preview).trimmingCharacters(in: .whitespacesAndNewlines), low = text.lowercased()
        let len = text.count, token = !text.contains(" ") && !text.contains("\n")
        let email = token && text.range(of: #"^[^\s@]+@[^\s@]+\.[a-z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
        let link = r.kind == "link", image = r.kind == "image", file = r.kind == "file", plain = r.kind == "text"
        let first = low.split(whereSeparator: { $0 == " " || $0 == "\n" }).first.map(String.init) ?? ""
        let command = plain && (cmds.contains(first) || low.hasPrefix("$ "))
        let path = plain && (text.hasPrefix("/") || text.hasPrefix("~/")) && len < 200 && !text.contains("\n")
        let code = plain && !command && codeMarks.filter { text.contains($0) }.count >= 2
        let greeting = plain && greetings.contains { low.hasPrefix($0) || low.contains("\n" + $0) } || low.contains("regards,") || low.contains("best,")
        let paragraph = plain && len > 80 && !code && !command
        var s = 3 / (1 + 0.25 * Double(rank))   // recency
        func add(_ b: Bool, _ v: Double) { if b { s += v } }
        switch cat {
        case .mail: add(email, 4); add(greeting, 3); add(paragraph, 2); add(link, 1); add(image, 0.5); add(code || command, -2)
        case .terminal: add(command, 5); add(path, 3.5); add(code, 2); add(link, 0.5); add(paragraph, -1); add(image || file, -1)
        case .code: add(code, 4.5); add(command, 3); add(path, 3); add(link, 1); add(paragraph, -0.5); add(image, -0.5)
        case .chat: add(plain && len < 200 && !code, 2); add(link, 2.5); add(image, 1); add(code, -1); add(len > 600, -1.5)
        case .browser: add(link, 5); add(email, 1); add(plain && len < 80, 1); add(code, -1)
        case .finder: add(file, 5); add(image, 2); add(path, 2.5)
        case .design: add(image, 5); add(file, 1.5); add(text.range(of: #"^#?[0-9a-f]{6}$"#, options: [.regularExpression, .caseInsensitive]) != nil, 3)
        case .writing: add(paragraph, 2); add(plain, 1); add(greeting, 1); add(image, 0.5); add(code || command, -1)
        case .other: break }
        return s
    }
    static func heuristic(_ rows: [Store.Row], bundle: String, title: String = "", limit: Int = count) -> [Int64] {
        let cat = category(bundle, title: title)
        let ranked = rows.prefix(40).enumerated().map { ($0.element.id, score($0.element, rank: $0.offset, cat: cat)) }
        return ranked.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    // MARK: entry point
    /// Calls `apply` at once (synchronously) with the heuristic or cached result; may call it once more later with the model's result.
    @MainActor static func request(app: NSRunningApplication?, rows: [Store.Row], apply: @escaping ([Store.Row], Source) -> Void) {
        inflight?.cancel(); inflight = nil
        let bundle = app?.bundleIdentifier ?? "", recent = Array(rows.prefix(40)), byID = Dictionary(recent.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func deliver(_ ids: [Int64], _ src: Source) { apply(ids.compactMap { byID[$0] }, src) }
        let key = bundle + "|" + recent.prefix(20).map { String($0.id) }.joined(separator: ",")
        if let hit = cache[key] { deliver(hit.0, hit.1); log("suggest: cache hit (\(hit.1.rawValue))"); return }
        let t0 = Date(), quick = heuristic(recent, bundle: bundle); deliver(quick, .heuristic)
        cache[key] = (quick, .heuristic)
        log("suggest: heuristic \(Int(Date().timeIntervalSince(t0) * 1000))ms for \(bundle)")
        guard modelAvailable else { return }
        let name = app?.localizedName ?? bundle, pid = app?.processIdentifier ?? 0
        inflight = Task { @MainActor in
            let started = Date()
            let ids = await Task.detached(priority: .userInitiated) { () -> [Int64]? in
                let title = windowTitle(pid)
                let refined = title.isEmpty ? quick : heuristic(recent, bundle: bundle, title: title)
                // the model only re-ranks the heuristic's 8 best candidates (tiny prompt, fewer wild picks)
                let top = heuristic(recent, bundle: bundle, title: title, limit: 8), pool = Dictionary(recent.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                guard let picked = await modelPick(name: name, bundle: bundle, title: title, rows: top.compactMap { pool[$0] }) else { return refined == quick ? nil : refined }
                return picked
            }.value
            guard !Task.isCancelled, let ids, !ids.isEmpty else { return }
            let src: Source = ids == quick ? .heuristic : .model
            cache[key] = (ids, src); deliver(ids, src)
            log("suggest: \(src.rawValue) result in \(Int(Date().timeIntervalSince(started) * 1000))ms")
        }
    }
    /// History content changed (edit / delete): forget cached picks.
    @MainActor static func invalidate() { cache.removeAll(); cancel() }
    @MainActor static func cancel() { inflight?.cancel(); inflight = nil }

    static func windowTitle(_ pid: pid_t) -> String {
        guard pid > 0, AXIsProcessTrusted() else { return "" }
        let app = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(app, 0.2)
        var w: CFTypeRef?, t: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &w) == .success, let win = w else { return "" }
        AXUIElementCopyAttributeValue(win as! AXUIElement, kAXTitleAttribute as CFString, &t)
        return String((t as? String ?? "").prefix(80))
    }

    // MARK: on-device model
    static var modelAvailable: Bool {
        guard Prefs.smartSuggestions else { return false }
        #if canImport(FoundationModels)
        if #available(macOS 26, *) { if case .available = SystemLanguageModel.default.availability { return true } }
        #endif
        return false
    }
    static var statusText: String {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "On-device model ready. Picks are refined by Apple Intelligence; nothing leaves this Mac."
            case .unavailable(let why): return "On-device model unavailable (\(why)). Using quick ranking by app and content type."
            @unknown default: return "On-device model status unknown. Using quick ranking." }
        }
        #endif
        return "On-device model needs macOS 26 or later. Using quick ranking by app and content type."
    }

    /// Plain-text reply ("3, 1, 7") parsed to ints: the @Generable macro plugin ships only with full Xcode, which the swiftc build does not require.
    static func numbers(_ s: String) -> [Int] { s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) } }
    static func modelPick(name: String, bundle: String, title: String, rows: [Store.Row]) async -> [Int64]? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            func line(_ i: Int, _ r: Store.Row) -> String {
                let t = r.kind == "image" || r.kind == "file" ? r.title : (r.preview.isEmpty ? r.title : r.preview)
                return "\(i + 1). [\(r.kind)] " + String(t.replacingOccurrences(of: "\n", with: " ").prefix(80))
            }
            let prompt = "App: \(name) (\(bundle))" + (title.isEmpty ? "" : "\nWindow: \(title)") + "\nClipboard items:\n" + rows.enumerated().map { line($0.offset, $0.element) }.joined(separator: "\n")
            do {
                let session = LanguageModelSession(instructions: "Pick the 3 clipboard items the user most likely wants to paste into the given app. Reply with only the 3 item numbers, comma separated, best first.")
                let r = try await withThrowingTaskGroup(of: [Int].self) { g in
                    g.addTask { Self.numbers(try await session.respond(to: prompt).content) }
                    g.addTask { try await Task.sleep(nanoseconds: 2_500_000_000); throw CancellationError() }
                    defer { g.cancelAll() }; return try await g.next() ?? []
                }
                var seen = Set<Int>(); let ids = r.filter { $0 >= 1 && $0 <= rows.count && seen.insert($0).inserted }.prefix(count).map { rows[$0 - 1].id }
                if ids.isEmpty { return nil }
                return Array((Array(ids) + rows.map(\.id).filter { !ids.contains($0) }).prefix(count))   // always 3 tiles
            } catch { log("suggest: model failed (\(error.localizedDescription))"); return nil }
        }
        #endif
        return nil
    }
}
