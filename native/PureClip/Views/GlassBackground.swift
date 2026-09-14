import AppKit
import SwiftUI

/// Panelin zemini: sistemin menü materyali, üstüne renk katmadan.
///
/// Electron sürümü CSS'te `linear-gradient(135deg, rgba(15,20,45,.4),
/// rgba(0,122,255,.12))` ile zemini lacivert/maviye boyuyordu ve bu ilk taşımada
/// birebir korunmuştu. Sonuç, yanındaki native menülerin yanında yabancı duruyordu:
/// macOS'un cam materyali arkasındaki içeriğin rengini geçirerek çalışır, üstüne
/// sabit bir renk sermek tam da o uyumu bozar.
///
/// Artık `.menu` materyali çıplak kullanılıyor — native menülerin, Spotlight'ın ve
/// sistem açılır panellerinin kullandığı materyalin aynısı. Açık/koyu tema, şeffaflık
/// ve macOS 26'daki Liquid Glass işlemesi böylece sistemden geliyor. Renk yalnızca
/// etkileşimli öğelerde (accent) kalıyor.
struct GlassBackground: View {
    /// macOS 26'da camı `ClipPanel` içindeki `NSGlassEffectView` sağlıyor; burada
    /// ikinci bir katman çizmek onu matlaştırır.
    private var systemDrawsGlass: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    var body: some View {
        Group {
            if systemDrawsGlass {
                Color.clear
            } else {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                            .strokeBorder(Theme.border, lineWidth: 0.5)
                    )
            }
        }
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
