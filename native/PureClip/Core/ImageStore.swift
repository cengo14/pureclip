import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Resimleri veritabanında değil diskte tutar.
///
/// Electron sürümü resimleri base64 data URL olarak SQLite'a yazıyordu: veri %33
/// şişiyor, sonra aynı dizi main process + IPC + renderer DOM'unda üç kopya hâlinde
/// bellekte duruyordu. Burada tam boy PNG diske yazılır, listede yalnızca küçük
/// resim (en uzun kenar 600 px) kullanılır; veritabanında sadece dosya adı durur.
final class ImageStore {
    private let fullDirectory: URL
    private let thumbnailDirectory: URL

    /// Küçük resimler için küçük bir bellek önbelleği — panel her açıldığında
    /// diskten yeniden çözülmesin diye.
    private let cache = NSCache<NSString, NSImage>()

    static let thumbnailMaxDimension: CGFloat = 600

    init(root: URL) {
        fullDirectory = root.appendingPathComponent("images", isDirectory: true)
        thumbnailDirectory = root.appendingPathComponent("thumbnails", isDirectory: true)

        for directory in [fullDirectory, thumbnailDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        cache.countLimit = 120
    }

    // MARK: - Yazma

    /// Panodan gelen resmi diske yazar. Dönen değer: (dosya adı, içerik hash'i).
    func save(_ image: NSImage) -> (fileName: String, hash: String)? {
        guard let pngData = Self.pngData(from: image) else { return nil }

        let hash = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        let fileName = "\(hash).png"

        let fullURL = fullDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: fullURL.path) {
            do {
                try pngData.write(to: fullURL, options: .atomic)
            } catch {
                NSLog("PureClip: resim yazılamadı — \(error.localizedDescription)")
                return nil
            }
        }

        writeThumbnailIfNeeded(from: pngData, fileName: fileName)
        return (fileName, hash)
    }

    /// Diskteki bir PNG/JPEG dosyasını (ör. masaüstü ekran görüntüsü) içeri alır.
    func save(contentsOf url: URL) -> (fileName: String, hash: String)? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return save(image)
    }

    /// Küçük resmi ImageIO ile üretir.
    ///
    /// `NSImage.lockFocus` kullanmak iki soruna yol açıyordu: Retina ekranda çizim
    /// geri ölçek faktörüyle (2x) yapıldığı için hedefin iki katı piksel üretiyor,
    /// ayrıca ara enterpolasyon görüntüyü sıkıştırılamaz hâle getirip küçük resmi
    /// tam boy resimden büyük yapıyordu. `CGImageSourceCreateThumbnailAtIndex`
    /// ise orijinali tam boyutta belleğe hiç açmadan doğrudan hedef boyutta çözer.
    private func writeThumbnailIfNeeded(from imageData: Data, fileName: String) {
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: thumbnailURL.path) else { return }

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(Self.thumbnailMaxDimension)
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let destination = CGImageDestinationCreateWithURL(
                  thumbnailURL as CFURL, UTType.png.identifier as CFString, 1, nil
              ) else { return }

        CGImageDestinationAddImage(destination, thumbnail, nil)
        CGImageDestinationFinalize(destination)
    }

    // MARK: - Okuma

    /// Liste görünümü için küçük resim. 5 MB'lık bir ekran görüntüsü burada
    /// ~100 KB'a iner — Electron sürümündeki ~7 MB base64 yerine.
    func thumbnail(named fileName: String) -> NSImage? {
        if let cached = cache.object(forKey: fileName as NSString) { return cached }

        let url = thumbnailDirectory.appendingPathComponent(fileName)
        let image = NSImage(contentsOf: url) ?? NSImage(contentsOf: fullDirectory.appendingPathComponent(fileName))

        if let image { cache.setObject(image, forKey: fileName as NSString) }
        return image
    }

    /// Panoya yazarken kullanılacak tam boy resim. Önbelleğe alınmaz — tek seferlik.
    func fullImage(named fileName: String) -> NSImage? {
        NSImage(contentsOf: fullDirectory.appendingPathComponent(fileName))
    }

    // MARK: - Silme

    func delete(fileNames: [String]) {
        for fileName in fileNames {
            try? FileManager.default.removeItem(at: fullDirectory.appendingPathComponent(fileName))
            try? FileManager.default.removeItem(at: thumbnailDirectory.appendingPathComponent(fileName))
            cache.removeObject(forKey: fileName as NSString)
        }
    }

    // MARK: - Görüntü yardımcıları

    private static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        return representation.representation(using: .png, properties: [:])
    }

}
