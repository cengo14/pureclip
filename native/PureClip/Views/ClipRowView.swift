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
        // Eylem ikonları alt satırda, zaman göstergesinin yanında.
        //
        // Önce içeriğin üzerine bindiriliyorlardı (uzun metin ve görsellerde
        // içerikle karışıyordu), sonra sağda dikey sütuna alındılar — bu sefer de
        // kartın minimum yüksekliğini ~140 pt'ye çıkarıp panelde görünen öğe
        // sayısını düşürdüler. Alt satır zaten var olduğu için burada ne binme
        // oluyor ne de ek yükseklik.
        VStack(alignment: .leading, spacing: 0) {
            content
            footer
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
        // Görsel düğmeler hover'a göre gelip gittiği için eylemler ayrıca burada
        // duruyor: ekran okuyucu ve klavye kullanıcıları için her zaman erişilebilir.
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Panoya Kopyala", onCopyOnly)
        .accessibilityAction(named: item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle", onTogglePin)
        .accessibilityAction(named: "Sil", onDelete)
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

    /// Bugünse yalnızca saat, dünse "Dün 13:55", bu yıl içindeyse "14 Eyl 13:55",
    /// daha eskiyse "14 Eyl 2025".
    ///
    /// Eskiden her kayıtta yalnızca saat yazıyordu: dünkü bir kayıtla bugünkünü
    /// ayırt etmek mümkün değildi.
    private var timestampText: String {
        let calendar = Calendar.current
        let date = item.createdAt

        if calendar.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        if calendar.isDateInYesterday(date) {
            return "Dün " + date.formatted(.dateTime.hour().minute())
        }
        if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Label {
                Text(timestampText)
            } icon: {
                Image(systemName: item.kind == .text ? "clock" : "photo")
            }
            .labelStyle(.titleAndIcon)
            .fixedSize()

            if let shortcut {
                // Rozet, hangi öğenin hangi tuşta olduğunu bakar bakmaz gösteriyor.
                Text(shortcut)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.pin.opacity(0.18), in: Capsule())
                    .foregroundStyle(Theme.pin)
                    .fixedSize()
            }

            Spacer(minLength: 4)

            actions
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
    /// Alt satırın sağındaki eylem düğmeleri.
    ///
    /// Boştayken yalnızca "etkin" olanlar duruyor (sabitliyse pin, kısayolu varsa
    /// klavye) ve sağa dayalı; hover'da diğerleri açılıp bunlar kendi sıralarına
    /// kayıyor. Gizli düğmelerin yerini ayırmak, tek başına duran pin simgesini
    /// kartın ortasında bırakıyor ve sağ taraf boş görünüyordu.
    ///
    /// Düğmeler hiyerarşiden çıktığı için erişilebilirlikten de düşerler; bu
    /// yüzden aynı eylemler karta `accessibilityAction` olarak bağlı ve hover'dan
    /// bağımsız olarak her zaman erişilebilir.
    private var actions: some View {
        HStack(spacing: 6) {
            if isHovering {
                IconButton(systemName: "doc.on.doc",
                           tint: Theme.text,
                           help: "Panoya Kopyala",
                           action: onCopyOnly)
                    .transition(.opacity)
            }

            if let slotMenu, isHovering || item.slot != nil {
                SlotMenuButton(menu: slotMenu)
                    .transition(.opacity)
            }

            if isHovering || item.isPinned {
                IconButton(systemName: "pin.fill",
                           tint: item.isPinned ? Theme.pin : Theme.text,
                           rotation: item.isPinned ? 0 : -45,
                           help: item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                           action: onTogglePin)
                    .transition(.opacity)
            }

            if isHovering {
                IconButton(systemName: "trash",
                           tint: Theme.text,
                           hoverTint: Theme.destructive,
                           help: "Sil",
                           action: onDelete)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isHovering)
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

/// Kısayol atama düğmesi.
///
/// SwiftUI `Menu` kendi ölçüsünü ve iç yerleşimini dayatıyor: kutusu diğer
/// düğmelerden geniş/basık çıkıyor ve simge ortalanmıyordu — ayrıca `label`
/// bloğuna verilen .background/.opacity yok sayılıyordu. Bu yüzden düğme gerçek
/// bir `IconButton`, menü ise AppKit'in `NSMenu`'sü. Görünüm diğer düğmelerle
/// birebir aynı, menü de sistemin kendi menüsü (işaretli öğe, ayırıcı, klavye
/// gezinme hepsi bedava).
struct SlotMenuButton: View {
    let menu: SlotMenu

    @State private var anchor = MenuAnchor()

    var body: some View {
        IconButton(systemName: "keyboard",
                   tint: menu.current != nil ? Theme.pin : Theme.text,
                   help: "Kısayol Ata") {
            anchor.present(menu)
        }
        .background(MenuAnchorView(anchor: anchor))
    }
}

/// Menünün altından açılacağı görünümü tutar.
final class MenuAnchor {
    weak var view: NSView?

    func present(_ model: SlotMenu) {
        guard let view else { return }

        let nsMenu = NSMenu()
        for slot in HistoryStore.slots {
            let key = model.label(slot)
            let title = model.occupant(slot).map { "\(key) — \($0)" } ?? key
            let item = ClosureMenuItem(title: title) { model.assign(slot) }
            // Atalı slot sistemin kendi onay işaretiyle gösteriliyor.
            item.state = model.current == slot ? .on : .off
            nsMenu.addItem(item)
        }

        if model.current != nil {
            nsMenu.addItem(.separator())
            nsMenu.addItem(ClosureMenuItem(title: "Kısayolu Kaldır") { model.clear() })
        }

        nsMenu.popUp(positioning: nil,
                     at: NSPoint(x: 0, y: view.bounds.height + 4),
                     in: view)
    }
}

/// Kapanış tutan menü öğesi — NSMenuItem hedef/eylem ikilisi yerine.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    @objc private func fire() { handler() }
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
