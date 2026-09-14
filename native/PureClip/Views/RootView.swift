import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 8) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.textSecondary)
                Text("PureClip")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Faz 1 — panel çalışıyor")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: Layout.panelWidth, height: Layout.panelHeight)
    }
}
