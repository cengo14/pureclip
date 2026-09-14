import Foundation

/// macOS ekran görüntülerini (⌘⇧3 / ⌘⇧4) geçmişe ekler.
///
/// Electron sürümü dosya adında `'Ekran Resmi'` veya `'Screenshot'` arıyordu; bu
/// yalnızca Türkçe ve İngilizce sistemlerde çalışıyor, kullanıcı varsayılan adı
/// değiştirdiyse hiç çalışmıyordu. Burada dosyanın
/// `com.apple.metadata:kMDItemIsScreenCapture` genişletilmiş özniteliğine bakılıyor:
/// bunu ekran görüntüsü servisinin kendisi yazıyor, dilden ve addan bağımsız.
final class ScreenshotWatcher {
    var onCapture: ((URL) -> Void)?

    private let directory: URL
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var seen: Set<String> = []
    private let startedAt = Date()

    private static let screenCaptureAttribute = "com.apple.metadata:kMDItemIsScreenCapture"
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "gif", "heic", "pdf"]

    init() {
        directory = Self.screenshotDirectory()
    }

    deinit {
        stop()
    }

    /// Kullanıcı ekran görüntüsü konumunu değiştirmiş olabilir
    /// (`defaults write com.apple.screencapture location ...`).
    private static func screenshotDirectory() -> URL {
        if let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            return URL(fileURLWithPath: (configured as NSString).expandingTildeInPath)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    func start() {
        guard source == nil else { return }

        descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            NSLog("PureClip: ekran görüntüsü klasörü izlenemedi (\(directory.path))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            // Dosyanın yazılması bitsin diye kısa bir gecikme.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.scan()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }

        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func scan() {
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        for url in contents where isNewScreenshot(url) {
            seen.insert(url.path)
            onCapture?(url)
        }
    }

    private func isNewScreenshot(_ url: URL) -> Bool {
        guard !seen.contains(url.path),
              Self.imageExtensions.contains(url.pathExtension.lowercased()) else { return false }

        // Uygulama açılmadan önce klasörde duran dosyalar geçmişe alınmaz.
        guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .isRegularFileKey]),
              values.isRegularFile == true,
              let created = values.creationDate,
              created >= startedAt else { return false }

        return Self.isScreenCapture(url)
    }

    /// Dosyada ekran görüntüsü özniteliği var mı. Değerin kendisini çözmeye gerek
    /// yok — özniteliğin varlığı işaretin kendisi.
    private static func isScreenCapture(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, screenCaptureAttribute, nil, 0, 0, 0) > 0
        }
    }
}
