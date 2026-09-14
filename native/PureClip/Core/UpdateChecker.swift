import Foundation

/// GitHub releases üzerinden sürüm kontrolü.
///
/// Electron sürümünde karşılaştırılan sürüm `'1.0.2'` olarak koda gömülüydü ama
/// package.json `1.0.0` diyordu; kontrol bu yüzden her zaman "yeni sürüm var"
/// diyordu. Burada sürüm `Bundle.main`'den okunuyor, tek kaynak Info.plist.
enum UpdateChecker {
    enum Result {
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private static let endpoint = URL(string: "https://api.github.com/repos/cengo14/pureclip/releases/latest")!

    static func check() async -> Result {
        struct Release: Decodable {
            let tagName: String
            let htmlURL: URL

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return .failed }

            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            return isNewer(latest, than: currentVersion)
                ? .available(version: latest, url: release.htmlURL)
                : .upToDate
        } catch {
            return .failed
        }
    }

    /// Sürümleri sayısal olarak karşılaştırır — "1.10.0" > "1.9.0" doğru sonuçlansın
    /// diye metin eşitliği yerine bileşen bileşen bakılıyor.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }

        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
