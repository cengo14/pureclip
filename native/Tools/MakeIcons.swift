// PureClip'in uygulama İÇİ logosunu üretir (başlıktaki 24 pt ve ayarlar alt
// bilgisindeki 64 pt ikon).
//
//   swift Tools/MakeIcons.swift PureClip/Assets.xcassets
//
// NOT: Uygulama ikonunun kendisi artık buradan gelmiyor. macOS 26'nın Liquid Glass
// sistemine katılabilmesi için ikon `PureClip/AppIcon.icon` paketinde katmanlı
// olarak duruyor (glif: Tools/make_glyph_svg.py, bileşim: AppIcon.icon/icon.json).
// Bu betik yalnızca o tasarımın düz, kendi kendine yeten PNG karşılığını üretir —
// uygulama içinde sistem kompozisyonu devrede olmadığı için gereklidir.

import AppKit
import SwiftUI

let canvas: CGFloat = 1024
let plate: CGFloat = 824
let corner: CGFloat = 185

// `background` adı SwiftUI'nin background(_:) değiştiricisiyle çakışıyor.
let plateGradient = LinearGradient(
    colors: [Color(red: 0.36, green: 0.66, blue: 1.00),
             Color(red: 0.02, green: 0.36, blue: 0.91)],
    startPoint: .top, endPoint: .bottom
)

/// Pano glifi: dik, ortalanmış, bol negatif alanlı. 16 pikselde bile silueti ve
/// satırları seçilebilsin diye kalın formlar ve yüksek kontrast kullanılıyor.
struct Clipboard: View {
    static let width: CGFloat = 420
    static let height: CGFloat = 510

    private let lineColor = Color(red: 0.62, green: 0.76, blue: 0.95)
    private let clipColor = Color(red: 0.80, green: 0.87, blue: 0.97)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 62, style: .continuous)
                .fill(.white)

            VStack(spacing: 46) {
                ForEach([1.0, 1.0, 0.64], id: \.self) { ratio in
                    Capsule()
                        .fill(lineColor)
                        .frame(width: (Self.width - 150) * ratio, height: 30)
                        .frame(width: Self.width - 150, alignment: .leading)
                }
            }
            .offset(y: 42)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(clipColor)
                    .frame(width: 210, height: 96)
                Circle()
                    .fill(.white)
                    .frame(width: 38, height: 38)
                    .offset(y: -6)
            }
            .offset(y: -Self.height / 2 + 18)
        }
        .frame(width: Self.width, height: Self.height)
        .offset(y: 14)
    }
}

/// `padded`: macOS uygulama ikonu (gölge ve kenar boşluğu dahil).
/// `padded == false`: uygulama içi logo — squircle tuvali doldurur, gölge yok,
/// çünkü 24 pt'lik bir başlık ikonunda boşluk sadece glifi küçültür.
struct Icon: View {
    let padded: Bool

    private var plateSize: CGFloat { padded ? plate : canvas }
    private var scale: CGFloat { plateSize / plate }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner * scale, style: .continuous)
                .fill(plateGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: corner * scale, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 3
                        )
                )
                .frame(width: plateSize, height: plateSize)
                .shadow(color: .black.opacity(padded ? 0.22 : 0), radius: 24, x: 0, y: 14)

            Clipboard().scaleEffect(scale)
        }
        .frame(width: canvas, height: canvas)
    }
}

// MARK: - Üretim

@MainActor
func render(_ view: some View, pixels: Int) -> Data? {
    let renderer = ImageRenderer(content: view.frame(width: canvas, height: canvas))
    renderer.scale = CGFloat(pixels) / canvas
    renderer.isOpaque = false

    guard let cgImage = renderer.cgImage else { return nil }
    return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
}

let assets = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1]
                                                                 : "PureClip/Assets.xcassets")
let logoSet = assets.appendingPathComponent("Logo.imageset")

MainActor.assumeIsolated {
    for (name, pixels) in [("logo.png", 256), ("logo@2x.png", 512)] {
        guard let data = render(Icon(padded: false), pixels: pixels) else { continue }
        try? data.write(to: logoSet.appendingPathComponent(name))
    }
    print("Logo: 2 boyut")
}
