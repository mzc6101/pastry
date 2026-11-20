// Pastry: user preferences (UserDefaults) and the global-hotkey model + registration.
import AppKit
import Carbon.HIToolbox

func log(_ s: String) { print("Pastry: \(s)"); fflush(stdout) }

enum Prefs {
    static let defaultIgnored = ["com.agilebits.onepassword7", "com.1password.1password", "com.apple.keychainaccess", "com.apple.Passwords",
                                 "com.bitwarden.desktop", "org.keepassxc.keepassxc", "com.lastpass.LastPass", "com.dashlane.dashlanephonefinal"]
    static let d: UserDefaults = {
        let d = UserDefaults.standard
        d.register(defaults: ["retentionDays": 0, "maxItems": 1000, "keepPinned": true, "playSound": false, "plainPaste": false, "smartSuggestions": true,
                              "ignoredApps": defaultIgnored, "hotKeyCode": Int(HotKey.default.code), "hotKeyMods": Int(HotKey.default.mods)])
        return d
    }()
    static var retentionDays: Int { get { d.integer(forKey: "retentionDays") } set { d.set(newValue, forKey: "retentionDays") } } // 0 = forever
    static var maxItems: Int { get { max(10, d.integer(forKey: "maxItems")) } set { d.set(newValue, forKey: "maxItems") } }
    static var keepPinned: Bool { get { d.bool(forKey: "keepPinned") } set { d.set(newValue, forKey: "keepPinned") } }
    static var playSound: Bool { get { d.bool(forKey: "playSound") } set { d.set(newValue, forKey: "playSound") } }
    static var plainPaste: Bool { get { d.bool(forKey: "plainPaste") } set { d.set(newValue, forKey: "plainPaste") } }
    static var smartSuggestions: Bool { get { d.bool(forKey: "smartSuggestions") } set { d.set(newValue, forKey: "smartSuggestions") } }
    static var axPrompted: Bool { get { d.bool(forKey: "axPrompted") } set { d.set(newValue, forKey: "axPrompted") } }
    static var ignoredApps: [String] { get { d.stringArray(forKey: "ignoredApps") ?? [] } set { d.set(newValue, forKey: "ignoredApps") } }
    static var hotKey: HotKey {
        get { HotKey(code: UInt32(d.integer(forKey: "hotKeyCode")), mods: UInt32(d.integer(forKey: "hotKeyMods"))) }
        set { d.set(Int(newValue.code), forKey: "hotKeyCode"); d.set(Int(newValue.mods), forKey: "hotKeyMods") }
    }
}

struct HotKey: Equatable {
    var code: UInt32, mods: UInt32   // Carbon virtual key + Carbon modifier mask
    static let `default` = HotKey(code: UInt32(kVK_ANSI_V), mods: UInt32(cmdKey | shiftKey))
    static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2",
        122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"]
    var display: String {
        (mods & UInt32(controlKey) != 0 ? "⌃" : "") + (mods & UInt32(optionKey) != 0 ? "⌥" : "") + (mods & UInt32(shiftKey) != 0 ? "⇧" : "")
            + (mods & UInt32(cmdKey) != 0 ? "⌘" : "") + (HotKey.names[code] ?? "key \(code)")
    }
    static func carbonMods(_ f: NSEvent.ModifierFlags) -> UInt32 {
        (f.contains(.command) ? UInt32(cmdKey) : 0) | (f.contains(.shift) ? UInt32(shiftKey) : 0)
            | (f.contains(.option) ? UInt32(optionKey) : 0) | (f.contains(.control) ? UInt32(controlKey) : 0)
    }
}

// One live Carbon hotkey. register() swaps atomically: the old key stays active if the new one is refused.
final class HotKeyManager {
    private var ref: EventHotKeyRef?
    private(set) var current: HotKey?
    private let onPress: () -> Void
    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ud in
            Unmanaged<HotKeyManager>.fromOpaque(ud!).takeUnretainedValue().onPress(); return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
    @discardableResult func register(_ k: HotKey) -> OSStatus {
        if k == current { return noErr }
        var new: EventHotKeyRef?
        let st = RegisterEventHotKey(k.code, k.mods, EventHotKeyID(signature: 0x50535452, id: 1), GetApplicationEventTarget(), 0, &new)
        log("hotkey \(k.display) register status=\(st)")
        if st == noErr { if let r = ref { UnregisterEventHotKey(r) }; ref = new; current = k }
        return st
    }
    static func explain(_ st: OSStatus, _ k: HotKey) -> String {
        st == OSStatus(eventHotKeyExistsErr) ? "\(k.display) is already used by another app or by macOS." : "\(k.display) could not be registered (error \(st))."
    }
}
