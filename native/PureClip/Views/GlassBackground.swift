import AppKit
import SwiftUI

/// Electron'daki `vibrancy: 'hud'` + `backdrop-filter: blur(40px) saturate(210%)`
/// görünümünün native karşılığı: sistem HUD materyali üzerine CSS'teki
/// `linear-gradient(135deg, var(--window-bg), rgba(0,122,255,0.12))` katmanı.
struct GlassBackground: View {
    var body: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .overlay(
                LinearGradient(
                    colors: [Theme.windowTint, Theme.accent.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
