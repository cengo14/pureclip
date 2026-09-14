import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ClipPanel!
    private var hotKey: HotKey?
    private var outsideClickMonitor: Any?
    private var store: HistoryStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()

        do {
            store = try HistoryStore()
        } catch {
            presentFatal(error)
            return
        }

        setUpStatusItem()
        setUpPanel()
        store.start()

        hotKey = HotKey(keyCode: KeyCode.v, modifiers: KeyModifier.command | KeyModifier.shift) { [weak self] in
            self?.togglePanel()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Menü çubuğu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "list.clipboard",
                               accessibilityDescription: "PureClip")
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
        panel.onResignKey = { [weak self] in self?.hidePanel() }
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
        positionPanel()
        panel.orderFrontRegardless()
        // .nonactivatingPanel sayesinde uygulama aktive olmaz — alttaki uygulama
        // "frontmost" kalır, böylece yapıştırma doğrudan oraya gider.
        panel.makeKey()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePanel()
        }
    }

    func hidePanel() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)

        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    /// Paneli menü çubuğu ikonunun altına, yatayda ortalayarak konumlandırır.
    private func positionPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size

        var x = buttonRect.midX - size.width / 2
        let y = buttonRect.minY - size.height - 6

        // Ekranın dışına taşmasın
        let visible = screen.visibleFrame
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
