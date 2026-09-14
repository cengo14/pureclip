import AppKit
import SwiftUI

/// Odağı çalmadan görünen, kenarlıksız, yuvarlak köşeli panel.
///
/// `.nonactivatingPanel` kritik: panel key olabilir (arama alanı yazı alır) ama
/// uygulama aktive olmaz, yani altta duran uygulama frontmost kalır. Electron
/// sürümündeki `app.hide()` + 500 ms bekleme hilesi bu sayede gereksizleşiyor.
///
/// Pencere, görünen panelden `shadowMargin` kadar büyük. Bu pay olmadan gölge
/// çizecek yer kalmıyordu: AppKit pencere gölgesini dikdörtgen çerçeveye göre
/// üretiyor ve yuvarlak camın arkasından keskin bir kare kenar sızıyordu. Artık
/// gölge, yuvarlak şeklin kendi katmanına çiziliyor ve bu saydam payın içinde
/// yayılıyor; pencerenin kendi gölgesi kapalı.
final class ClipPanel: NSPanel {
    /// Paneli kapatma isteği (Esc). Uygulamanın aktifliğini kaybetmesi ayrı bir
    /// yoldan, AppDelegate'teki `didResignActiveNotification` ile ele alınıyor.
    var onDismiss: (() -> Void)?

    /// Gölgenin yayılması için pencerenin dört yanında bırakılan saydam pay.
    static let shadowMargin: CGFloat = 28

    /// Panelin görünen (cam) kısmının boyutu — pencere bundan daha büyük.
    static let visibleSize = NSSize(width: Layout.panelWidth, height: Layout.panelHeight)

    private let glassContainer: NSView

    init(rootView: AnyView) {
        let margin = Self.shadowMargin
        let visible = Self.visibleSize

        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear

        // İçerik her durumda yuvarlatılıyor. NSGlassEffectView yalnızca kendi cam
        // katmanını yuvarlatıyor; contentView'ı kare kaldığı için köşelerde camın
        // arkasından keskin bir kenar sızıyordu.
        hosting.layer?.cornerRadius = Layout.cornerRadius
        hosting.layer?.cornerCurve = .continuous   // Apple'ın squircle eğrisi
        hosting.layer?.masksToBounds = true

        if #available(macOS 26.0, *) {
            // macOS 26'da camı sistem çiziyor. NSVisualEffectView ile taklit etmek
            // eski (legacy) materyali veriyor ve yanındaki gerçek menülerin yanında
            // mat duruyordu; NSGlassEffectView ise menülerin, Spotlight'ın ve
            // Denetim Merkezi'nin kullandığı asıl Liquid Glass katmanı.
            let glass = NSGlassEffectView()
            glass.cornerRadius = Layout.cornerRadius
            glass.style = .regular
            glass.contentView = hosting
            glassContainer = glass
        } else {
            glassContainer = hosting
        }

        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: visible.width + margin * 2,
                                height: visible.height + margin * 2),
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
        // Pencere gölgesi kapalı: dikdörtgen çerçeveye çizildiği için köşelerde
        // keskin kenar bırakıyordu. Yerine aşağıda yuvarlak şekle gölge veriliyor.
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .utilityWindow

        // Saydam taşıyıcı: gölge bunun içinde yayılıyor.
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true

        glassContainer.frame = NSRect(x: margin, y: margin,
                                      width: visible.width, height: visible.height)
        glassContainer.autoresizingMask = []
        container.addSubview(glassContainer)
        contentView = container

        applyShadow()
    }

    /// Gölgeyi yuvarlak şeklin katmanına verir. `shadowPath` olmadan Core Animation
    /// gölgeyi katmanın alfasından çıkarır; açık bir yol vermek hem daha ucuz hem de
    /// köşelerin tam olarak takip edilmesini garantiler.
    private func applyShadow() {
        guard let layer = glassContainer.layer else { return }

        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: -8)
        layer.masksToBounds = false
        layer.shadowPath = CGPath(
            roundedRect: glassContainer.bounds,
            cornerWidth: Layout.cornerRadius,
            cornerHeight: Layout.cornerRadius,
            transform: nil
        )
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
