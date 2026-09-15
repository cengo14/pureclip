import Foundation
import SQLite3

/// `libsqlite3` üzerine ince bir sarmalayıcı. SwiftData/Core Data yerine ham SQLite
/// tercih edildi: tek tablo, tam sorgu kontrolü, sıfır bağımlılık ve VACUUM erişimi.
final class Database {
    private var db: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: URL) throws {
        guard sqlite3_open_v2(path.path, &db,
                              SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
                              nil) == SQLITE_OK else {
            throw Failure.open(message)
        }

        try exec("PRAGMA journal_mode = WAL;")
        try exec("PRAGMA synchronous = NORMAL;")
        // Sıra önemli: önce tablo, sonra sütun göçleri, en sonra indeksler.
        // Benzersiz slot indeksi `slot` sütununa dayandığı için göçten önce
        // oluşturulamaz — denenirse sqlite3_exec hata verir ve uygulama açılışta
        // düşer (bu sırayla bir kez yaşandı).
        try exec("""
            CREATE TABLE IF NOT EXISTS clips (
                id          TEXT PRIMARY KEY,
                kind        INTEGER NOT NULL,
                text        TEXT,
                image_file  TEXT,
                hash        TEXT NOT NULL,
                pinned      INTEGER NOT NULL DEFAULT 0,
                pinned_at   REAL,
                slot        INTEGER,
                created_at  REAL NOT NULL
            );
            """)

        migrate()

        try exec("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_clips_hash  ON clips(hash);
            CREATE INDEX        IF NOT EXISTS idx_clips_order ON clips(pinned DESC, pinned_at ASC, created_at DESC);
            -- Bir slot aynı anda tek öğede olabilir; kısmi indeks bunu veritabanı
            -- düzeyinde garanti ediyor (NULL'lar kısıtlamanın dışında).
            CREATE UNIQUE INDEX IF NOT EXISTS idx_clips_slot  ON clips(slot) WHERE slot IS NOT NULL;
            """)
    }

    /// Şema göçleri. SQLite'ta "varsa ekleme" yok; sütun zaten varsa ALTER hata
    /// verir, bu beklenen durum olduğu için yutuluyor.
    private func migrate() {
        if (try? exec("ALTER TABLE clips ADD COLUMN pinned_at REAL;")) != nil {
            // Yeni sütun: mevcut sabitlenmiş kayıtlara bir sıra ver.
            try? exec("UPDATE clips SET pinned_at = created_at WHERE pinned = 1 AND pinned_at IS NULL;")
        }
        try? exec("ALTER TABLE clips ADD COLUMN slot INTEGER;")
    }

    deinit {
        sqlite3_close_v2(db)
    }

    enum Failure: LocalizedError {
        case open(String)
        case statement(String)

        var errorDescription: String? {
            switch self {
            case .open(let m): return "Veritabanı açılamadı: \(m)"
            case .statement(let m): return "SQL hatası: \(m)"
            }
        }
    }

    private var message: String {
        String(cString: sqlite3_errmsg(db))
    }

    // MARK: - Okuma

    /// En yeni kayıtlar önce, sabitlenmişler en üstte. Resim verisi değil yalnızca
    /// dosya adı döner — büyük içerik hiçbir zaman belleğe alınmaz.
    func fetchAll(limit: Int) -> [ClipItem] {
        let sql = """
            SELECT id, kind, text, image_file, hash, pinned, pinned_at, slot, created_at
            FROM clips
            ORDER BY pinned DESC, (slot IS NULL), slot ASC, pinned_at ASC, created_at DESC
            LIMIT ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var items: [ClipItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            items.append(ClipItem(
                id: column(stmt, 0) ?? UUID().uuidString,
                kind: ClipItem.Kind(rawValue: Int(sqlite3_column_int(stmt, 1))) ?? .text,
                text: column(stmt, 2),
                imageFile: column(stmt, 3),
                hash: column(stmt, 4) ?? "",
                isPinned: sqlite3_column_int(stmt, 5) == 1,
                pinnedAt: sqlite3_column_type(stmt, 6) == SQLITE_NULL
                    ? nil
                    : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6)),
                slot: sqlite3_column_type(stmt, 7) == SQLITE_NULL
                    ? nil
                    : Int(sqlite3_column_int(stmt, 7)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
            ))
        }
        return items
    }

    private func column(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    // MARK: - Yazma

    /// Kayıt yoksa ekler; aynı hash varsa yalnızca zaman damgasını tazeler
    /// (böylece listenin başına çıkar, sabitleme durumu korunur).
    /// Dönen değer: gerçekten yeni bir kayıt eklendi mi.
    @discardableResult
    func upsert(_ item: ClipItem) -> Bool {
        let sql = """
            INSERT INTO clips (id, kind, text, image_file, hash, pinned, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(hash) DO UPDATE SET created_at = excluded.created_at;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, item.id, -1, Self.transient)
        sqlite3_bind_int(stmt, 2, Int32(item.kind.rawValue))
        bindOptional(stmt, 3, item.text)
        bindOptional(stmt, 4, item.imageFile)
        sqlite3_bind_text(stmt, 5, item.hash, -1, Self.transient)
        sqlite3_bind_int(stmt, 6, item.isPinned ? 1 : 0)
        sqlite3_bind_double(stmt, 7, item.createdAt.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        // Çakışma olduysa satır eski id'sini korur, bizim yeni id'miz tabloya hiç
        // girmez. Dolayısıyla id'nin varlığı "gerçekten yeni kayıt" demektir.
        return exists(id: item.id)
    }

    private func exists(id: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM clips WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private func bindOptional(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, Self.transient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    /// Sabitleme kaldırılırken atanmış kısayol da temizleniyor: sabitlenmemiş bir
    /// öğenin kısayolu olması kullanıcı için anlamsız olurdu.
    func togglePin(id: String) {
        run("""
            UPDATE clips
            SET pinned    = 1 - pinned,
                pinned_at = CASE WHEN pinned = 0 THEN ? ELSE NULL END,
                slot      = CASE WHEN pinned = 0 THEN slot ELSE NULL END
            WHERE id = ?;
            """) { stmt in
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, id, -1, Self.transient)
        }
    }

    /// Slotu bu öğeye verir. Slot başkasındaysa ondan alınır — kullanıcı menüde
    /// hangi slotun dolu olduğunu görüyor, dolayısıyla bu bilinçli bir devralma.
    func assignSlot(_ slot: Int, to id: String) {
        try? exec("BEGIN IMMEDIATE;")
        run("UPDATE clips SET slot = NULL WHERE slot = ?;") { stmt in
            sqlite3_bind_int(stmt, 1, Int32(slot))
        }
        run("UPDATE clips SET slot = ? WHERE id = ?;") { stmt in
            sqlite3_bind_int(stmt, 1, Int32(slot))
            sqlite3_bind_text(stmt, 2, id, -1, Self.transient)
        }
        try? exec("COMMIT;")
    }

    func clearSlot(id: String) {
        run("UPDATE clips SET slot = NULL WHERE id = ?;") { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
        }
    }

    // MARK: - Silme
    //
    // Silen her metot, artık sahipsiz kalan resim dosyalarının adlarını döner;
    // çağıran taraf bunları diskten temizler (yetim dosya kalmasın).

    func delete(id: String) -> [String] {
        let orphans = imageFiles(matching: "WHERE id = ?") { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
        }
        run("DELETE FROM clips WHERE id = ?;") { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
        }
        return orphans
    }

    func deleteUnpinned() -> [String] {
        let orphans = imageFiles(matching: "WHERE pinned = 0")
        run("DELETE FROM clips WHERE pinned = 0;")
        return orphans
    }

    func deleteOlderThan(_ date: Date) -> [String] {
        let bind: (OpaquePointer?) -> Void = { stmt in
            sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
        }
        let orphans = imageFiles(matching: "WHERE pinned = 0 AND created_at < ?", bind: bind)
        run("DELETE FROM clips WHERE pinned = 0 AND created_at < ?;", bind: bind)
        return orphans
    }

    /// Sabitlenmemiş kayıt sayısını `limit` değerine indirir, en eskiden başlayarak.
    func enforceLimit(_ limit: Int) -> [String] {
        let subquery = """
            SELECT id FROM clips WHERE pinned = 0
            ORDER BY created_at DESC LIMIT -1 OFFSET ?
            """
        let bind: (OpaquePointer?) -> Void = { stmt in
            sqlite3_bind_int(stmt, 1, Int32(limit))
        }
        let orphans = imageFiles(matching: "WHERE id IN (\(subquery))", bind: bind)
        run("DELETE FROM clips WHERE id IN (\(subquery));", bind: bind)
        return orphans
    }

    private func imageFiles(matching clause: String,
                            bind: ((OpaquePointer?) -> Void)? = nil) -> [String] {
        var stmt: OpaquePointer?
        let sql = "SELECT image_file FROM clips \(clause) AND image_file IS NOT NULL;"
        // `WHERE ... AND` kurulumu için clause zaten WHERE ile başlıyor.
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        bind?(stmt)

        var files: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let file = column(stmt, 0) { files.append(file) }
        }
        return files
    }

    /// Silinen satırların yerini geri kazanır. Electron sürümünde bu hiç çalışmadığı
    /// için 7 MB veri 76 MB'lık bir dosyada duruyordu.
    func vacuum() {
        try? exec("VACUUM;")
    }

    /// WAL dosyasındaki kaydedilmiş sayfaları ana veritabanına aktarıp WAL'ı
    /// kısaltır. Uygulama kapanırken çağrılıyor ki diskte yüzlerce KB'lık bir
    /// yardımcı dosya asılı kalmasın.
    func checkpoint() {
        sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
    }

    // MARK: - Yardımcılar

    private func run(_ sql: String, bind: ((OpaquePointer?) -> Void)? = nil) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        sqlite3_step(stmt)
    }

    private func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let text = error.map { String(cString: $0) } ?? message
            sqlite3_free(error)
            throw Failure.statement(text)
        }
    }
}
