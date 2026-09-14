import Foundation

/// Liste üstündeki kategori sekmeleri.
enum ClipFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:   return "Tümü"
        case .text:  return "Metin"
        case .image: return "Görsel"
        }
    }

    var icon: String {
        switch self {
        case .all:   return "square.stack"
        case .text:  return "textformat"
        case .image: return "photo"
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all:   return true
        case .text:  return item.kind == .text
        case .image: return item.kind == .image
        }
    }
}

/// Sıralama ölçütü. Sabitlenmiş öğeler ölçütten bağımsız olarak hep en üstte kalır.
enum ClipSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest:       return "En Yeni Önce"
        case .oldest:       return "En Eski Önce"
        case .alphabetical: return "A - Z"
        }
    }

    var icon: String {
        switch self {
        case .newest:       return "arrow.down"
        case .oldest:       return "arrow.up"
        case .alphabetical: return "textformat.abc"
        }
    }

    /// İki öğeyi karşılaştırır. Sabitleme önceliği çağıran tarafta uygulanıyor.
    func isOrderedBefore(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
        switch self {
        case .newest:
            return lhs.createdAt > rhs.createdAt
        case .oldest:
            return lhs.createdAt < rhs.createdAt
        case .alphabetical:
            // Resimlerin aranabilir metni yok; onları alfabetik listenin sonuna al.
            let left = lhs.previewText
            let right = rhs.previewText
            if left.isEmpty != right.isEmpty { return right.isEmpty }
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }
}
