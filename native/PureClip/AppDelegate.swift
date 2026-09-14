import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ClipPanel!
    private var hotKey: HotKey?
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
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
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
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
        let size = panel.frame.size
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        // Menü çubuğu öğesi henüz yerleşmediyse (uygulama yeni açıldıysa) buton
        // dikdörtgeni sıfıra yakın gelir ve panel ekranın altına düşer. Böyle bir
        // durumda menü çubuğunun sağ ucuna yaslıyoruz.
        let isButtonPlaced = buttonRect.minY > visible.minY + size.height

        var x = isButtonPlaced ? buttonRect.midX - size.width / 2 : visible.maxX - size.width - 8
        let y = isButtonPlaced ? buttonRect.minY - size.height - 6 : visible.maxY - size.height - 6

        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
