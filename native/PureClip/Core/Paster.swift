import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Otomatik yapıştırma.
///
/// Electron sürümü bunun için `osascript -e 'tell application "System Events" to
/// keystroke "v" using command down'` çalıştırıyordu: ayrı bir process, AppleScript
/// derlemesi ve panelin kapanmasını beklemek için 500 ms'lik sabit gecikme.
/// `CGEvent` aynı tuş vuruşunu doğrudan olay akışına koyar.
enum Paster {
    /// Erişilebilirlik izni var mı (kullanıcıya dialog göstermeden).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// macOS'un kendi izin dialogunu gösterir. Kullanıcıyı Sistem Ayarları'na
    /// yollamaktan daha iyi: dialog uygulamayı erişilebilirlik listesine kendisi
    /// ekler, kullanıcının listeden elle bulup sürüklemesi gerekmez.
    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Öndeki uygulamaya ⌘V gönderir.
    static func sendCommandV() {
        guard isTrusted else { return }
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        // Kullanıcı o an başka değiştirici tuşlara basıyorsa bunlar olayımıza
        // karışmasın diye yerel olayları kısa süre bastırıyoruz.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)

        down?.flags = .maskCommand
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
