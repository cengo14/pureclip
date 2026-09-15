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
    @ObservationIgnored private let screenshots = ScreenshotWatcher()

    /// Paneli kapatması için AppDelegate'in bağladığı kanca.
    @ObservationIgnored var onRequestHide: (() -> Void)?

    /// İzin dialogunu oturum başına bir kez gösterelim, her tıklamada değil.
    @ObservationIgnored private var didRequestAccessibility = false

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

        if AppSettings.watchScreenshots {
            screenshots.onCapture = { [weak self] url in
                self?.captureScreenshot(at: url)
            }
            screenshots.start()
        }

        runCleanup()
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }
        timer.tolerance = 5 * 60
        RunLoop.main.add(timer, forMode: .common)
        cleanupTimer = timer
    }

    /// Uygulama kapanırken: izleyicileri durdur, WAL'ı ana dosyaya aktar.
    func shutdown() {
        monitor.stop()
        screenshots.stop()
        cleanupTimer?.invalidate()
        db.checkpoint()
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
                pinnedAt: nil,
                slot: nil,
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
                pinnedAt: nil,
                slot: nil,
                createdAt: Date()
            )
        }

        add(item)
    }

    /// Masaüstüne (ya da kullanıcının seçtiği klasöre) düşen ekran görüntüsünü alır.
    ///
    /// Electron sürümü yakaladığı dosyayı kullanıcıya sormadan siliyordu. Burada
    /// silme `deleteScreenshotAfterCapture` ayarına bağlı ve varsayılanı kapalı —
    /// kullanıcının dosyası izinsiz kaybolmuyor.
    private func captureScreenshot(at url: URL) {
        guard let saved = images.save(contentsOf: url) else { return }

        add(ClipItem(
            id: UUID().uuidString,
            kind: .image,
            text: nil,
            imageFile: saved.fileName,
            hash: saved.hash,
            isPinned: false,
            pinnedAt: nil,
            slot: nil,
            createdAt: Date()
        ))

        if AppSettings.deleteScreenshotAfterCapture {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                NSLog("PureClip: ekran görüntüsü çöpe taşınamadı — \(error.localizedDescription)")
            }
        }
    }

    private func add(_ item: ClipItem) {
        let isNew = db.upsert(item)

        if isNew {
            images.delete(fileNames: db.enforceLimit(AppSettings.historyLimit))
            if AppSettings.soundEnabled { Sound.captured.play() }
        }

        reload()
    }

    /// Kısayol atanabilecek slot numaraları.
    static let slots = 1...5

    /// Verilen slota atanmış öğe. Kısayol basıldığında bu çözümleniyor.
    func item(inSlot slot: Int) -> ClipItem? {
        items.first { $0.slot == slot && $0.isPinned }
    }

    /// Kullanıcı bir slotu bir öğeye atar. Slot başkasındaysa ondan alınır.
    func assign(slot: Int, to item: ClipItem) {
        db.assignSlot(slot, to: item.id)
        reload()
    }

    func clearSlot(of item: ClipItem) {
        db.clearSlot(id: item.id)
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

        // Kullanılan öğe yeniden kopyalanmış sayılıyor: zaman damgası tazeleniyor,
        // böylece listede sabitlenmişlerin hemen ardına, en başa geliyor.
        // Panoya kendimiz yazdığımız için izleyici bunu yakalamıyor; damgayı
        // burada elle atmazsak öğe bulunduğu yerde kalırdı.
        db.touch(id: item.id)
        reload()

        if AppSettings.soundEnabled { Sound.captured.play() }
    }

    /// Kullanıcı bir öğeye tıkladığında: panoya yaz, paneli kapat, öndeki uygulamaya
    /// ⌘V gönder.
    ///
    /// Yalnızca panoya kopyalar ve paneli kapatır — yapıştırma yok. Otomatik
    /// yapıştırma kapalıyken kullanıcının içeriği alıp kendi ⌘V'siyle yapıştırması
    /// için; açıkken de "yapıştırmadan sadece kopyala" seçeneği olarak duruyor.
    func copyOnly(_ item: ClipItem) {
        copyToPasteboard(item)
        onRequestHide?()
    }

    /// Panel açık değilken (kısayol slotları) kullanılır: öndeki uygulama zaten
    /// hedef olduğu için paneli kapatmaya ya da odağı iade etmeye gerek yok.
    func pasteDirectly(_ item: ClipItem) {
        copyToPasteboard(item)

        guard AppSettings.autoPaste else { return }
        guard Paster.isTrusted else {
            requestAccessibilityOnce()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Paster.sendCommandV()
        }
    }

    /// `onRequestHide` paneli kapatıp odağı panel açılmadan önceki uygulamaya
    /// iade eder; ⌘V o uygulama öne geldikten sonra gönderilir. Electron sürümü
    /// hedefi bilmediği için `app.hide()` deyip 500 ms tahminî bekliyordu.
    func paste(_ item: ClipItem) {
        copyToPasteboard(item)
        onRequestHide?()

        guard AppSettings.autoPaste else { return }

        guard Paster.isTrusted else {
            requestAccessibilityOnce()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Paster.sendCommandV()
        }
    }

    /// Kullanıcı yapıştırma bekliyor ama izin yok. Ayarlarda düğme aramak yerine
    /// sistemin izin dialogunu tam ihtiyaç duyulduğu anda gösteriyoruz; oturum
    /// başına bir kez, her tıklamada tekrarlamasın.
    private func requestAccessibilityOnce() {
        guard !didRequestAccessibility else { return }
        didRequestAccessibility = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Paster.requestTrust()
        }
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
