import AppKit
import SwiftUI

/// Electron sürümünün ölçüleri (BrowserWindow 350×500, köşe 14 px).
enum Layout {
    static let panelWidth: CGFloat = 350
    static let panelHeight: CGFloat = 500
    static let cornerRadius: CGFloat = 14
    static let cardCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 12
}

/// `src/index.css` içindeki CSS değişkenlerinin birebir Swift karşılığı.
/// Açık/koyu tema, CSS'teki `prefers-color-scheme` bloğuyla aynı değerleri kullanır.
enum Theme {
    static let accent = Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)       // #007AFF
    static let accentGlow = Color(red: 0, green: 122 / 255, blue: 1, opacity: 0.4)

    static let windowTint = dynamic(
        dark: NSColor(srgbRed: 15 / 255, green: 20 / 255, blue: 45 / 255, alpha: 0.40),
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.40)
    )

    static let cardBackground = dynamic(
        dark: NSColor(white: 1.0, alpha: 0.05),
        light: NSColor(white: 0.0, alpha: 0.04)
    )

    static let cardBackgroundHover = dynamic(
        dark: NSColor(white: 1.0, alpha: 0.15),
        light: NSColor(white: 0.0, alpha: 0.09)
    )

    static let headerBackground = dynamic(
        dark: NSColor(white: 1.0, alpha: 0.02),
        light: NSColor(white: 0.0, alpha: 0.02)
    )

    static let text = dynamic(
        dark: NSColor(white: 1.0, alpha: 1.0),
        light: NSColor(srgbRed: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1.0)
    )

    static let textSecondary = dynamic(
        dark: NSColor(white: 1.0, alpha: 0.60),
        light: NSColor(white: 0.0, alpha: 0.55)
    )

    static let border = dynamic(
        dark: NSColor(white: 1.0, alpha: 0.10),
        light: NSColor(white: 0.0, alpha: 0.08)
    )

    static let destructive = Color(red: 1.0, green: 0x3B / 255, blue: 0x30 / 255) // #ff3b30

    private static func dynamic(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
