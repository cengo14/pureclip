import Foundation

struct ClipItem: Identifiable, Hashable {
    enum Kind: Int {
        case text = 0
        case image = 1
    }

    let id: String
    let kind: Kind
    /// Yalnızca `.text` için dolu.
    let text: String?
    /// Yalnızca `.image` için dolu — `ImageStore` içindeki dosya adı (veri değil, ad).
    let imageFile: String?
    /// İçeriğin SHA-256'sı. Tekrar eden girdileri indeksli kolonda yakalamak için;
    /// Electron sürümündeki `WHERE content = ?` tam taramasının yerini alıyor.
    let hash: String
    var isPinned: Bool
    /// Ne zaman sabitlendiği — sabitlenmiş öğelerin kendi aralarındaki sırası.
    let pinnedAt: Date?
    /// Kullanıcının bu öğeye atadığı kısayol slotu (1-5), atanmadıysa nil.
    /// Sabitleme kaldırılınca temizleniyor.
    let slot: Int?
    let createdAt: Date

    var previewText: String {
        text ?? ""
    }
}
