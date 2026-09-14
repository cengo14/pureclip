import AppKit
import SwiftUI

/// Odağı çalmadan görünen, kenarlıksız, yuvarlak köşeli panel.
///
/// `.nonactivatingPanel` kritik: panel key olabilir (arama alanı yazı alır) ama
/// uygulama aktive olmaz, yani altta duran uygulama frontmost kalır. Electron
/// sürümündeki `app.hide()` + 500 ms bekleme hilesi bu sayede gereksizleşiyor.
final class ClipPanel: NSPanel {
    /// Paneli kapatma isteği (Esc). Uygulamanın aktifliğini kaybetmesi ayrı bir
    /// yoldan, AppDelegate'teki `didResignActiveNotification` ile ele alınıyor.
    var onDismiss: (() -> Void)?

    init(rootView: AnyView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .utilityWindow

        let hosting = NSHostingView(rootView: rootView)

        if #available(macOS 26.0, *) {
            // macOS 26'da camı sistem çiziyor. NSVisualEffectView ile taklit etmek
            // eski (legacy) menü görünümünü veriyor ve yanındaki gerçek menülerin
            // yanında mat duruyordu; NSGlassEffectView ise menülerin, Spotlight'ın
            // ve Denetim Merkezi'nin kullandığı asıl Liquid Glass katmanı.
            let glass = NSGlassEffectView()
            glass.cornerRadius = Layout.cornerRadius
            glass.style = .regular
            glass.contentView = hosting
            contentView = glass
        } else {
            hosting.wantsLayer = true
            hosting.layer?.cornerRadius = Layout.cornerRadius
            hosting.layer?.masksToBounds = true
            contentView = hosting
        }
    }

    // Kenarlıksız pencereler varsayılan olarak key olamaz; arama alanının yazı
    // alabilmesi için buna izin veriyoruz.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // NOT: Burada `resignKey`i geçersiz kılıp paneli gizlemek cazip görünüyor ama
    // yanlış: onay dialogu panele bir sheet olarak açıldığında panel key olmaktan
    // çıkıyor, dolayısıyla dialog görünmeden panel kapanıyordu. Kapatma sinyali
    // pencerenin key'liği değil, uygulamanın aktifliği olmalı.

    /// Esc paneli kapatsın — ama üstte bir onay dialogu varsa Esc önce onu iptal
    /// etmeli, o yüzden sheet açıkken karışmıyoruz.
    override func cancelOperation(_ sender: Any?) {
        guard attachedSheet == nil else { return }
        onDismiss?()
    }
}
