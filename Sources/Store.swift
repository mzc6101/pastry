// Pastry: SQLite history store with retention.
import Foundation
import CryptoKit
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
let thumbUTI = "com.manavchordia.pastry.thumbnail"   // PNG preview stored next to a copied image *file* (never pasted back)

final class Store {
    static var defaultPath: String {
        let env = ProcessInfo.processInfo.environment
        return env["PASTRY_DB"] ?? env["PASTECLONE_DB"] ?? NSHomeDirectory() + "/Library/Application Support/Pastry/history.sqlite"
    }
    var db: OpaquePointer?
    init(path: String) {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        guard sqlite3_open(path, &db) == SQLITE_OK else { fatalError("cannot open db") }
        exec("PRAGMA journal_mode=WAL")
        exec("""
        CREATE TABLE IF NOT EXISTS item(id INTEGER PRIMARY KEY, checksum TEXT UNIQUE, kind TEXT, title TEXT,
          app_bundle TEXT, app_name TEXT, created REAL, pinboard TEXT, preview TEXT, meta TEXT);
        CREATE TABLE IF NOT EXISTS item_data(item_id INTEGER REFERENCES item(id) ON DELETE CASCADE, uti TEXT, data BLOB);
        CREATE INDEX IF NOT EXISTS item_created ON item(created DESC);
        PRAGMA foreign_keys=ON;
        """)
        exec("ALTER TABLE item ADD COLUMN preview TEXT"); exec("ALTER TABLE item ADD COLUMN meta TEXT") // migrate older DBs (fails harmlessly if present)
    }
    @discardableResult func exec(_ sql: String) -> Bool { sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK }
    func scalar(_ sql: String) -> Int { var st: OpaquePointer?; sqlite3_prepare_v2(db, sql, -1, &st, nil); defer { sqlite3_finalize(st) }
        return sqlite3_step(st) == SQLITE_ROW ? Int(sqlite3_column_int64(st, 0)) : 0 }
    var count: Int { scalar("SELECT COUNT(*) FROM item") }

    func upsert(kind: String, title: String, preview: String, meta: String, app: (String, String), flavors: [(String, Data)]) {
        var h = SHA256(); for (t, d) in flavors { h.update(data: Data(t.utf8)); h.update(data: d) }
        let sum = h.finalize().map { String(format: "%02x", $0) }.joined()
        var st: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT id FROM item WHERE checksum=?", -1, &st, nil)
        sqlite3_bind_text(st, 1, sum, -1, SQLITE_TRANSIENT)
        if sqlite3_step(st) == SQLITE_ROW { // duplicate: bump to top
            let id = sqlite3_column_int64(st, 0); sqlite3_finalize(st)
            exec("UPDATE item SET created=\(Date().timeIntervalSince1970) WHERE id=\(id)"); return
        }
        sqlite3_finalize(st)
        sqlite3_prepare_v2(db, "INSERT INTO item(checksum,kind,title,app_bundle,app_name,created,preview,meta) VALUES(?,?,?,?,?,?,?,?)", -1, &st, nil)
        sqlite3_bind_text(st, 1, sum, -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 2, kind, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(st, 3, title, -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 4, app.0, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(st, 5, app.1, -1, SQLITE_TRANSIENT); sqlite3_bind_double(st, 6, Date().timeIntervalSince1970)
        sqlite3_bind_text(st, 7, preview, -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 8, meta, -1, SQLITE_TRANSIENT)
        sqlite3_step(st); sqlite3_finalize(st)
        let id = sqlite3_last_insert_rowid(db)
        for (t, d) in flavors {
            sqlite3_prepare_v2(db, "INSERT INTO item_data VALUES(?,?,?)", -1, &st, nil)
            sqlite3_bind_int64(st, 1, id); sqlite3_bind_text(st, 2, t, -1, SQLITE_TRANSIENT)
            _ = d.withUnsafeBytes { sqlite3_bind_blob(st, 3, $0.baseAddress, Int32(d.count), SQLITE_TRANSIENT) }
            sqlite3_step(st); sqlite3_finalize(st)
        }
        enforce()
    }

    // Retention: drop items older than the age limit, then trim to the max count. Pinned items are exempt when keepPinned.
    @discardableResult func enforce(now: Date = Date()) -> Int {
        let before = count, guardPin = Prefs.keepPinned ? " AND pinboard IS NULL" : ""
        if Prefs.retentionDays > 0 { exec("DELETE FROM item WHERE created < \(now.timeIntervalSince1970 - Double(Prefs.retentionDays) * 86400)\(guardPin)") }
        exec("DELETE FROM item WHERE 1\(guardPin) AND id NOT IN (SELECT id FROM item WHERE 1\(guardPin) ORDER BY created DESC LIMIT \(Prefs.maxItems))")
        return purged(before)
    }
    @discardableResult func clearAll() -> Int { let before = count; exec("DELETE FROM item WHERE 1\(Prefs.keepPinned ? " AND pinboard IS NULL" : "")"); return purged(before) }
    private func purged(_ before: Int) -> Int {
        let n = before - count
        if n > 0 { Visual.thumbCache.removeAll(); exec("PRAGMA wal_checkpoint(PASSIVE)"); log("removed \(n) item(s) from history") }
        return n
    }

    struct Row { var id: Int64; var kind: String; var title: String; var app: String; var bundle: String; var created: Double; var pin: String?; var preview: String; var meta: String }
    func search(_ q: String, pinboard: String? = nil) -> [Row] {
        var st: OpaquePointer?
        var sql = "SELECT id,kind,title,app_name,created,pinboard,preview,meta,app_bundle FROM item WHERE (title LIKE ? OR app_name LIKE ? OR preview LIKE ?)"
        if pinboard != nil { sql += " AND pinboard IS NOT NULL" }
        sql += " ORDER BY created DESC LIMIT 200"
        sqlite3_prepare_v2(db, sql, -1, &st, nil)
        let pat = "%\(q)%"
        sqlite3_bind_text(st, 1, pat, -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 2, pat, -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 3, pat, -1, SQLITE_TRANSIENT)
        var out: [Row] = []
        while sqlite3_step(st) == SQLITE_ROW {
            func s(_ i: Int32) -> String { sqlite3_column_text(st, i).map { String(cString: $0) } ?? "" }
            out.append(Row(id: sqlite3_column_int64(st, 0), kind: s(1), title: s(2), app: s(3), bundle: s(8), created: sqlite3_column_double(st, 4),
                           pin: sqlite3_column_type(st, 5) == SQLITE_NULL ? nil : s(5), preview: s(6), meta: s(7)))
        }
        sqlite3_finalize(st); return out
    }
    func flavors(_ id: Int64) -> [(String, Data)] {
        var st: OpaquePointer?; var out: [(String, Data)] = []
        sqlite3_prepare_v2(db, "SELECT uti,data FROM item_data WHERE item_id=?", -1, &st, nil)
        sqlite3_bind_int64(st, 1, id)
        while sqlite3_step(st) == SQLITE_ROW {
            let t = String(cString: sqlite3_column_text(st, 0)); let n = Int(sqlite3_column_bytes(st, 1))
            out.append((t, n == 0 ? Data() : Data(bytes: sqlite3_column_blob(st, 1), count: n)))
        }
        sqlite3_finalize(st); return out
    }
    func delete(_ id: Int64) { exec("DELETE FROM item_data WHERE item_id=\(id)"); exec("DELETE FROM item WHERE id=\(id)"); Visual.thumbCache[id] = nil; Visual.sourceCache[id] = nil }
    /// Replace a text/link item's content in place (id, pin, app, time stay). Rich flavors are dropped; the checksum follows the new text unless that would collide.
    func updateText(_ id: Int64, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
        Visual.sourceCache[id] = nil
        let data = Data(t.utf8), uti = "public.utf8-plain-text"
        var h = SHA256(); h.update(data: Data(uti.utf8)); h.update(data: data)
        let sum = h.finalize().map { String(format: "%02x", $0) }.joined(), isURL = URL(string: t)?.scheme?.hasPrefix("http") == true && !t.contains(" ")
        exec("DELETE FROM item_data WHERE item_id=\(id)")
        var st: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO item_data VALUES(?,?,?)", -1, &st, nil)
        sqlite3_bind_int64(st, 1, id); sqlite3_bind_text(st, 2, uti, -1, SQLITE_TRANSIENT)
        _ = data.withUnsafeBytes { sqlite3_bind_blob(st, 3, $0.baseAddress, Int32(data.count), SQLITE_TRANSIENT) }
        sqlite3_step(st); sqlite3_finalize(st)
        sqlite3_prepare_v2(db, "UPDATE OR IGNORE item SET kind=?, title=?, preview=?, meta=?, checksum=? WHERE id=?", -1, &st, nil)
        sqlite3_bind_text(st, 1, isURL ? "link" : "text", -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 2, String(t.prefix(300)).replacingOccurrences(of: "\n", with: " "), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(st, 3, String(t.prefix(1500)), -1, SQLITE_TRANSIENT); sqlite3_bind_text(st, 4, "\(t.count) character\(t.count == 1 ? "" : "s")", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(st, 5, sum, -1, SQLITE_TRANSIENT); sqlite3_bind_int64(st, 6, id)
        sqlite3_step(st); sqlite3_finalize(st)
    }
    func togglePin(_ id: Int64) { exec("UPDATE item SET pinboard = CASE WHEN pinboard IS NULL THEN 'Pinned' ELSE NULL END WHERE id=\(id)") }
}
