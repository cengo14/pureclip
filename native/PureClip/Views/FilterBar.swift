import SwiftUI

/// Arama alanının altındaki kategori sekmeleri ve sıralama menüsü.
///
/// Geçmiş yüz kayda çıktığında aradığını gözle taramak zorlaşıyor; kategori
/// metin/görsel ayrımını, sıralama da zaman ekseninde gezinmeyi hızlandırıyor.
struct FilterBar: View {
    @Binding var filter: ClipFilter
    @Binding var sort: ClipSort

    /// Kategori başına toplam sayı (arama sonucundan değil, tüm geçmişten).
    let counts: [ClipFilter: Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ClipFilter.allCases) { option in
                FilterChip(
                    filter: option,
                    count: counts[option] ?? 0,
                    isSelected: filter == option
                ) {
                    filter = option
                }
            }

            Spacer(minLength: 4)

            sortMenu
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sıralama", selection: $sort) {
                ForEach(ClipSort.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sıralama: \(sort.title)")
    }
}

private struct FilterChip: View {
    let filter: ClipFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(filter.title)
                    .font(.system(size: 11, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.65)
                }
            }
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : Theme.border, lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: isHovering)
    }

    private var background: Color {
        if isSelected { return Theme.accent }
        return isHovering ? Theme.cardBackgroundHover : Theme.cardBackground
    }
}
