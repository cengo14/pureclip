import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ClipPanel!
    private var hotKey: HotKey?
    /// Sabitlenmiş öğe slotları (⌘⇧1-5). Ayar değişince yeniden kaydediliyor.
    private var pinnedHotKeys: [HotKey] = []
    private var registeredPinnedConfig: (enabled: Bool, modifier: PinnedShortcutModifier)?
    private var store: HistoryStore!

    /// Panel açılmadan hemen önceki öndeki uygulama. Yapıştırmadan önce odağı
    /// buna geri veriyoruz — Electron sürümü `app.hide()` deyip 500 ms bekleyerek
    /// "herhalde eski uygulama öne gelmiştir" varsayımıyla çalışıyordu; burada
    /// hedef uygulama kesin olarak biliniyor.
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()
        applyDevelopmentAppearanceOverride()

        do {
            store = try HistoryStore()
        } catch {
            presentFatal(error)
            return
        }

        store.onRequestHide = { [weak self] in self?.hideAndRestoreFocus() }

        setUpStatusItem()
        setUpPanel()
        store.start()

        registerPinnedHotKeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // Ayarlar penceresinde kısayol tercihi değişince kayıtları tazele.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        hotKey = HotKey(keyCode: KeyCode.v, modifiers: KeyModifier.command | KeyModifier.shift) { [weak self] in
            self?.togglePanel()
        }

        // Geliştirme kolaylığı: paneli açık başlat (görsel doğrulama / ekran görüntüsü).
        // Menü çubuğu öğesi konumlanana kadar bekle, yoksa panel ekran dışına düşer.
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.togglePanel()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.shutdown()
    }

    @objc private func settingsDidChange() {
        registerPinnedHotKeys()
    }

    /// Sabitlenmiş öğe kısayollarını (değiştirici + 1-5) kaydeder.
    ///
    /// Carbon kısayolları `HotKey` serbest bırakılınca çözülüyor, bu yüzden önce
    /// dizi boşaltılıyor. Ayar değişmediyse hiçbir şey yapılmıyor: bu metot her
    /// UserDefaults değişiminde çağrılıyor ve gereksiz yeniden kayıt, kullanıcı
    /// tuşa basmışken kısayolu kısa süreliğine ölü bırakabilir.
    private func registerPinnedHotKeys() {
        let config = (enabled: AppSettings.pinnedShortcutsEnabled,
                      modifier: AppSettings.pinnedShortcutModifier)

        if let current = registeredPinnedConfig,
           current.enabled == config.enabled, current.modifier == config.modifier {
            return
        }
        registeredPinnedConfig = config

        pinnedHotKeys.removeAll()
        guard config.enabled else { return }

        pinnedHotKeys = KeyCode.digits.enumerated().compactMap { index, keyCode in
            HotKey(keyCode: keyCode, modifiers: config.modifier.carbonMask) { [weak self] in
                self?.pastePinnedSlot(index + 1)   // slotlar 1 tabanlı
            }
        }
    }

    /// Slot kısayolu: panel açıksa normal yol (kapat, odağı iade et, yapıştır),
    /// kapalıysa öndeki uygulama zaten hedef olduğu için doğrudan yapıştır.
    private func pastePinnedSlot(_ slot: Int) {
        guard let item = store.item(inSlot: slot) else {
            NSSound.beep()   // bu slota bir öğe atanmamış
            return
        }

        if panel.isVisible {
            store.paste(item)
        } else {
            store.pasteDirectly(item)
        }
    }

    /// Uygulama aktifliğini kaybettiğinde panel kapanır: kullanıcı başka bir
    /// uygulamaya ya da masaüstüne tıkladı demektir. Panel içindeki onay dialogu
    /// bu bildirimi tetiklemez — eskiden kullanılan `resignKey` ise tetikliyor,
    /// dialog görünmeden paneli kapatıyordu.
    @objc private func applicationDidResignActive() {
        guard panel?.attachedSheet == nil else { return }
        hidePanel()
    }

    /// Geliştirme kolaylığı: `--appearance dark|light` ile sistem temasından
    /// bağımsız olarak iki görünümü de test edebilmek için.
    private func applyDevelopmentAppearanceOverride() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--appearance"),
              index + 1 < arguments.count else { return }

        switch arguments[index + 1] {
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default:      break
        }
    }

    // MARK: - Menü çubuğu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "PureClip")
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
        button.toolTip = "PureClip"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        // Olay yoksa (ör. erişilebilirlik API'si üzerinden tetiklendiğinde) sol
        // tık varsayılıyor; eskiden burada erken dönülüyor ve tıklama sessizce
        // yutuluyordu.
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "PureClip'i Göster", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Uygulamadan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // menüyü tek seferlik göster, sol tık davranışını geri ver
    }

    // MARK: - Panel

    private func setUpPanel() {
        panel = ClipPanel(rootView: AnyView(RootView(store: store)))
        panel.onDismiss = { [weak self] in self?.hidePanel() }
    }

    private func presentFatal(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "PureClip başlatılamadı"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }

    @objc func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        // Hangi uygulamaya geri döneceğimizi paneli göstermeden önce not al.
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }

        // Ayarlar panel içinde değiştiği için tercih değişikliği normalde
        // UserDefaults bildirimiyle anında uygulanıyor. Panel her açılışta da
        // yeniden senkronlanıyor: bildirim kaçarsa (ör. ayar başka bir süreçten
        // değiştiyse) kısayollar en geç burada güncellenir. Yapılandırma
        // değişmediyse metot erken dönüyor, maliyeti yok.
        registerPinnedHotKeys()

        positionPanel()

        // Arama alanının klavye girişi alabilmesi için uygulamanın öne gelmesi
        // gerekiyor: macOS klavye olaylarını yalnızca aktif uygulamaya yönlendirir.
        // Odak kaybı `previousApp` sayesinde yapıştırma anında telafi ediliyor.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        guard panel.isVisible, panel.attachedSheet == nil else { return }
        panel.orderOut(nil)
    }

    /// Paneli kapatıp odağı panel açılmadan önceki uygulamaya iade eder.
    /// Yapıştırma bunun hemen ardından gidiyor.
    private func hideAndRestoreFocus() {
        hidePanel()

        if let previousApp, !previousApp.isTerminated {
            previousApp.activate()
        } else {
            NSApp.hide(nil)
        }
        previousApp = nil
    }

    /// Paneli menü çubuğu ikonunun altına, yatayda ortalayarak konumlandırır.
    private func positionPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        // Pencere, gölgeye yer açmak için görünen panelden dört yanda
        // `shadowMargin` kadar büyük. Konum hesabı görünen kısma göre yapılıp
        // pencere başlangıcı o kadar geri kaydırılıyor.
        let size = ClipPanel.visibleSize
        let margin = ClipPanel.shadowMargin
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        // Menü çubuğu öğesi henüz yerleşmediyse (uygulama yeni açıldıysa) buton
        // dikdörtgeni sıfıra yakın gelir ve panel ekranın altına düşer. Böyle bir
        // durumda menü çubuğunun sağ ucuna yaslıyoruz.
        let isButtonPlaced = buttonRect.minY > visible.minY + size.height

        var x = isButtonPlaced ? buttonRect.midX - size.width / 2 : visible.maxX - size.width - 8
        let y = isButtonPlaced ? buttonRect.minY - size.height - 6 : visible.maxY - size.height - 6

        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)

        panel.setFrameOrigin(NSPoint(x: x - margin, y: y - margin))
    }
}
