import SwiftUI

@main
struct PureClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // PureClip bir menü çubuğu uygulaması (LSUIElement). Görünür bir pencere
        // sahnesi yok; her şeyi AppDelegate'teki NSStatusItem + NSPanel yönetiyor.
        // Settings sahnesi yalnızca App protokolünü karşılamak için burada.
        Settings { EmptyView() }
    }
}
