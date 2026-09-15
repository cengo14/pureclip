import SwiftUI

/// `.item-card` — padding 14, köşe 12, 0.5 px kenarlık; sabitlenmişler turuncu
/// gradyanlı. Hover'da eylem düğmeleri beliriyor (CSS'teki `opacity: 0` → `1`).
struct ClipRowView: View {
    let item: ClipItem
    let thumbnail: NSImage?
    /// Atanmış kısayolun etiketi, ör. "⌘⇧1". Slot atanmamışsa ya da özellik
    /// kapalıysa nil.
    var shortcut: String?
    /// Kısayol atama menüsü. Yalnızca sabitlenmiş öğelerde ve özellik açıkken dolu.
    var slotMenu: SlotMenu?

    let onCopy: () -> Void
    /// Yalnızca panoya kopyalar, yapıştırmaz. Otomatik yapıştırma açıkken bile
    /// "sadece kopyala" mümkün olsun diye ayrı bir eylem.
    let onCopyOnly: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        // İkonlar eskiden içeriğin üzerine bindiriliyordu (.overlay) ve metne
        // sabit 45 pt sağ boşluk bırakılıyordu. Üçüncü düğme eklenince bu yetmedi,
        // görsellerde ise hiç boşluk yoktu — ikonlar içeriğin üstüne biniyordu.
        // Artık kendi sütunlarında: yerleşimin parçası oldukları için binmeleri
        // mümkün değil.
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                content
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(item.isPinned ? Theme.pinnedBorder : Theme.border, lineWidth: 0.5)
        )
        .offset(y: isHovering ? -1 : 0) // .item-card:hover { transform: translateY(-1px) }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.25), value: isHovering)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.previewText)
                .font(.system(size: 13))
                .lineSpacing(13 * 0.4)          // line-height: 1.4
                .lineLimit(4)                    // -webkit-line-clamp: 4
                .multilineTextAlignment(.leading)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .image:
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 150)   // .item-image { max-height: 150px }
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var footer: some View {
        HStack {
            Label {
                Text(item.createdAt, format: .dateTime.hour().minute())
            } icon: {
                Image(systemName: item.kind == .text ? "clock" : "photo")
            }
            .labelStyle(.titleAndIcon)

            Spacer()

            if let shortcut {
                // Rozet, hangi öğenin hangi tuşta olduğunu bakar bakmaz gösteriyor.
                Text(shortcut)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.pin.opacity(0.18), in: Capsule())
                    .foregroundStyle(Theme.pin)
            } else if item.isPinned {
                Text("Sabitlendi")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.pin)
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.textSecondary)
        .padding(.top, 10)
    }

    /// CSS'te bu düğmeler `opacity: 0` ile başlayıp `.item-card:hover` ile
    /// görünür oluyor. Aynı görsel davranış korunuyor, ancak saydamlık düğmenin
    /// tamamına değil içeriğine uygulanıyor: sabitlenmiş öğelerde pin düğmesi
    /// hover olmadan da görünür kalıyor ve her iki düğme de erişilebilirlik
    /// ağacında duruyor.
    /// Sağdaki dikey eylem sütunu. Düğmeler hover'da beliriyor ama yerleri her
    /// zaman ayrılı: göründüklerinde içerik yeniden akmıyor.
    private var actions: some View {
        VStack(spacing: 6) {
            IconButton(systemName: "doc.on.doc",
                       revealed: isHovering,
                       tint: Theme.text,
                       help: "Panoya Kopyala",
                       action: onCopyOnly)

            if let slotMenu {
                SlotMenuButton(menu: slotMenu, revealed: isHovering || item.slot != nil)
            }

            IconButton(systemName: "pin.fill",
                       revealed: isHovering || item.isPinned,
                       tint: item.isPinned ? Theme.pin : Theme.text,
                       rotation: item.isPinned ? 0 : -45,
                       help: item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                       action: onTogglePin)

            IconButton(systemName: "trash",
                       revealed: isHovering,
                       tint: Theme.text,
                       hoverTint: Theme.destructive,
                       help: "Sil",
                       action: onDelete)
        }
    }

    @ViewBuilder
    private var background: some View {
        if item.isPinned {
            Theme.pinnedFill
        } else {
            isHovering ? Theme.cardBackgroundHover : Theme.cardBackground
        }
    }
}

/// `.action-button` (kart üzerindeki pin/sil) ve `.header-icon-button` (başlık).
///
/// Aradaki fark CSS'ten geliyor: `.action-button` duran hâlde de `var(--card-bg)`
/// arka planına sahipken `.header-icon-button` `background: none` ile başlar ve
/// arka planı yalnızca hover'da kazanır.
struct IconButton: View {
    enum Style {
        /// Kart üzerindeki eylem düğmesi — her zaman arka planlı.
        case filled
        /// Başlık düğmesi — arka plan yalnızca hover'da.
        case plain
    }

    let systemName: String
    var style: Style = .filled
    /// Görsel olarak görünür mü. `false` iken düğme saydam çizilir ama yerleşimde
    /// ve erişilebilirlik ağacında kalır — `.opacity(0)`'ı düğmenin tamamına
    /// uygulamak onu VoiceOver'dan da gizliyordu.
    var revealed = true
    var tint: Color = Theme.textSecondary
    var hoverTint: Color?
    var rotation: Double = 0
    var size: CGFloat = 14
    var padding: CGFloat = 4
    var cornerRadius: CGFloat = 6
    var help: String = ""
    let action: () -> Void

    @State private var isHovering = false

    private var background: Color {
        switch (style, isHovering) {
        case (.filled, false): return Theme.cardBackground
        case (.filled, true), (.plain, true): return Theme.cardBackgroundHover
        case (.plain, false): return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .rotationEffect(.degrees(rotation))
                // SF Symbols'te glif yükseklikleri değişiyor (ör. "keyboard"
                // basık, "trash" uzun). Sabit çerçeve olmadan arka plan kutuları
                // farklı boylarda çıkıyordu.
                .frame(width: size + 2, height: size + 2)
                .foregroundStyle(isHovering ? (hoverTint ?? tint) : tint)
                .padding(padding)
                .background(background, in: RoundedRectangle(cornerRadius: cornerRadius))
                .opacity(revealed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
        .animation(.easeOut(duration: 0.2), value: isHovering)
        .animation(.easeOut(duration: 0.2), value: revealed)
    }
}


/// Bir kartın kısayol atama menüsünün ihtiyaç duyduğu her şey.
struct SlotMenu {
    /// Öğeye şu an atalı slot (1-5), yoksa nil.
    let current: Int?
    /// Slot -> gösterilecek kısayol etiketi, ör. 1 -> "⌘⇧1".
    let label: (Int) -> String
    /// Slot başka bir öğedeyse onun kısa açıklaması, boşsa nil.
    let occupant: (Int) -> String?
    let assign: (Int) -> Void
    let clear: () -> Void
}

/// `.action-button` görünümünde bir menü düğmesi: 1-5 arası slotlardan birini
/// seçtirir. Dolu slotlar işaretleniyor — seçince devralınacağı sürpriz olmasın.
struct SlotMenuButton: View {
    let menu: SlotMenu
    var revealed: Bool

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(Array(HistoryStore.slots), id: \.self) { slot in
                Button {
                    menu.assign(slot)
                } label: {
                    Text(title(for: slot))
                }
            }

            if menu.current != nil {
                Divider()
                Button("Kısayolu Kaldır", role: .destructive) { menu.clear() }
            }
        } label: {
            // Yalnızca simge; arka plan ve saydamlık aşağıda, Menu'nün kendisine
            // uygulanıyor. `label` bloğuna verilen .background/.opacity SwiftUI
            // tarafından yok sayılıyordu — düğme diğerlerinden farklı, arka
            // plansız görünüyordu.
            Image(systemName: "keyboard")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 16, height: 16)   // kart eylem düğmeleriyle aynı kutu
                .padding(4)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(menu.current != nil ? Theme.pin : Theme.text)
        .background(isHovering ? Theme.cardBackgroundHover : Theme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 6))
        .opacity(revealed ? 1 : 0)
        .onHover { isHovering = $0 }
        .help("Kısayol Ata")
        .accessibilityLabel("Kısayol Ata")
        .animation(.easeOut(duration: 0.2), value: revealed)
    }

    private func title(for slot: Int) -> String {
        let key = menu.label(slot)
        if menu.current == slot { return "✓ \(key)" }
        if let occupant = menu.occupant(slot) { return "\(key) — \(occupant)" }
        return key
    }
}
