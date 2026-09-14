import SwiftUI

struct RootView: View {
    let store: HistoryStore

    var body: some View {
        ZStack {
            GlassBackground()

            // Faz 2 geçici görünümü — Faz 3'te gerçek liste gelecek.
            VStack(alignment: .leading, spacing: 6) {
                Text("\(store.items.count) kayıt")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                ForEach(store.items.prefix(12)) { item in
                    Text(item.kind == .text ? item.previewText : "🖼 \(item.imageFile ?? "")")
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(Theme.text)
                }
                Spacer()
            }
            .padding(Layout.horizontalPadding)
        }
        .frame(width: Layout.panelWidth, height: Layout.panelHeight)
    }
}
