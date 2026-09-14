import AppKit

/// Panoyu `NSPasteboard.changeCount` üzerinden izler.
///
/// Electron sürümü 500 ms'de bir `clipboard.readImage().toDataURL()` çağırıyordu —
/// pano hiç değişmemiş olsa bile tüm resmi base64'e çeviriyor, saniyede onlarca MB
/// çöp üretiyordu. Burada tik başına yapılan tek iş bir `Int` karşılaştırması;
/// panonun içeriğine ancak sayaç ilerlediğinde dokunuluyor.
final class ClipboardMonitor {
    enum Payload {
        case text(String)
        case image(NSImage)
    }

    var onChange: ((Payload) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    private static let interval: TimeInterval = 0.35

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Zamanlayıcıların birleştirilebilmesi için tolerans: daha az uyanma, daha az pil.
        timer.tolerance = Self.interval / 3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Panoya kendimiz yazdıktan sonra çağrılır; kendi yazdığımızı geçmişe
    /// tekrar eklemeyelim diye sayaç hizalanır.
    func acknowledgeSelfWrite() {
        lastChangeCount = pasteboard.changeCount
    }

    private func tick() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return } // sıcak yol: sadece bir Int karşılaştırması
        lastChangeCount = current

        guard let payload = readPayload() else { return }
        onChange?(payload)
    }

    private func readPayload() -> Payload? {
        // Metin öncelikli: bir ekran görüntüsü kopyalandığında panoda metin olmaz,
        // metin kopyalandığında da resim olmaz. Her ikisini bağımsız kontrol etmek
        // (Electron sürümündeki gibi) aynı kopyalamayı iki kez eklemeye yol açıyordu.
        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return .text(trimmed)
            }
        }

        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        guard pasteboard.availableType(from: imageTypes) != nil,
              let image = NSImage(pasteboard: pasteboard) else {
            return nil
        }
        return .image(image)
    }
}
