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
    /// Ne zaman sabitlendiği. Kısayol slotları (⌘⇧1-5) bu sıraya göre dağıtılıyor:
    /// ilk sabitlenen 1 numara olur ve yeni sabitlemeler sona eklenir, böylece
    /// mevcut slotlar kaymaz. Yakalanma zamanına göre sıralamak bunu bozuyordu.
    let pinnedAt: Date?
    let createdAt: Date

    var previewText: String {
        text ?? ""
    }
}
