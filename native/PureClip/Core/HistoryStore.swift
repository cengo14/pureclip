import AppKit
import CryptoKit
import Observation

/// Pano geçmişinin tek sahibi: izleyici, veritabanı ve resim deposunu birbirine bağlar.
@Observable
final class HistoryStore {
    private(set) var items: [ClipItem] = []

    @ObservationIgnored let images: ImageStore
    @ObservationIgnored private let db: Database
    @ObservationIgnored private let monitor = ClipboardMonitor()
    @ObservationIgnored private var cleanupTimer: Timer?

    /// Uygulama verisinin kök dizini. Electron sürümünün `history.db` dosyasına
    /// dokunulmaz — native sürüm ayrı bir `clips.db` kullanır, böylece iki sürüm
    /// yan yana çalışabilir.
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("PureClip", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    init() throws {
        let root = Self.supportDirectory
        db = try Database(path: root.appendingPathComponent("clips.db"))
        images = ImageStore(root: root)

        reload()

        monitor.onChange = { [weak self] payload in
            self?.capture(payload)
        }
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    // MARK: - Yaşam döngüsü

    func start() {
        monitor.start()

        runCleanup()
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }
        timer.tolerance = 5 * 60
        RunLoop.main.add(timer, forMode: .common)
        cleanupTimer = timer
    }

    // MARK: - Yakalama

    private func capture(_ payload: ClipboardMonitor.Payload) {
        let item: ClipItem

        switch payload {
        case .text(let text):
            item = ClipItem(
                id: UUID().uuidString,
                kind: .text,
                text: text,
                imageFile: nil,
                hash: Self.hash(of: Data(text.utf8)),
                isPinned: false,
                createdAt: Date()
            )

        case .image(let image):
            guard let saved = images.save(image) else { return }
            item = ClipItem(
                id: UUID().uuidString,
                kind: .image,
                text: nil,
                imageFile: saved.fileName,
                hash: saved.hash,
                isPinned: false,
                createdAt: Date()
            )
        }

        add(item)
    }

    /// Masaüstünden yakalanan ekran görüntüleri için (ScreenshotWatcher kullanır).
    func captureImage(at url: URL) {
        guard let saved = images.save(contentsOf: url) else { return }

        add(ClipItem(
            id: UUID().uuidString,
            kind: .image,
            text: nil,
            imageFile: saved.fileName,
            hash: saved.hash,
            isPinned: false,
            createdAt: Date()
        ))
    }

    private func add(_ item: ClipItem) {
        let isNew = db.upsert(item)

        if isNew {
            images.delete(fileNames: db.enforceLimit(AppSettings.historyLimit))
            if AppSettings.soundEnabled { Sound.captured.play() }
        }

        reload()
    }

    // MARK: - Kullanıcı eylemleri

    func togglePin(_ item: ClipItem) {
        db.togglePin(id: item.id)
        reload()
    }

    func delete(_ item: ClipItem) {
        images.delete(fileNames: db.delete(id: item.id))
        reload()
    }

    func clearUnpinned() {
        images.delete(fileNames: db.deleteUnpinned())
        db.vacuum()
        reload()
    }

    /// Öğeyi panoya yazar. `acknowledgeSelfWrite` sayesinde kendi yazdığımız içerik
    /// geçmişe yeniden eklenmez.
    func copyToPasteboard(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            guard let text = item.text else { return }
            let value = AppSettings.pasteAsPlainText ? text.trimmingCharacters(in: .whitespacesAndNewlines) : text
            pasteboard.setString(value, forType: .string)

        case .image:
            guard let fileName = item.imageFile,
                  let image = images.fullImage(named: fileName) else { return }
            pasteboard.writeObjects([image])
        }

        monitor.acknowledgeSelfWrite()
        if AppSettings.soundEnabled { Sound.captured.play() }
    }

    // MARK: - Bakım

    private func runCleanup() {
        let cutoff = Date().addingTimeInterval(-Double(AppSettings.autoCleanupDays) * 24 * 60 * 60)
        var orphans = db.deleteOlderThan(cutoff)
        orphans += db.enforceLimit(AppSettings.historyLimit)

        if !orphans.isEmpty {
            images.delete(fileNames: orphans)
            db.vacuum()
        }
        reload()
    }

    private func reload() {
        items = db.fetchAll(limit: AppSettings.historyLimit)
    }

    private static func hash(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
