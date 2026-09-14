// PureClip uygulama ikonunu ve uygulama içi logoyu üretir.
//
//   swift Tools/MakeIcons.swift
//
// Çıktı doğrudan Assets.xcassets içine yazılır. İkonu değiştirmek için aşağıdaki
// tasarımı düzenleyip betiği yeniden çalıştırmak yeterli; PNG'leri elle
// düzenlemeye gerek yok.
//
// Geometri Apple'ın macOS ikon ızgarasına uyar: 1024 tuvalde 824x824 squircle,
// sürekli (continuous) köşe, yumuşak gölge ve squircle dışında saydam alan.
// Eski ikonun en büyük kusuru buydu — koyu kare bir zemin PNG'ye gömülüydü,
// dolayısıyla Dock'ta yuvarlak köşeli değil kare bir blok olarak görünüyordu.

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
let appIconSet = assets.appendingPathComponent("AppIcon.appiconset")
let logoSet = assets.appendingPathComponent("Logo.imageset")

MainActor.assumeIsolated {
    var manifest: [[String: String]] = []

    for size in [16, 32, 128, 256, 512] {
        for scaleFactor in [1, 2] {
            let pixels = size * scaleFactor
            let name = "icon_\(size)x\(size)@\(scaleFactor)x.png"
            guard let data = render(Icon(padded: true), pixels: pixels) else { continue }
            try? data.write(to: appIconSet.appendingPathComponent(name))
            manifest.append(["filename": name, "idiom": "mac",
                             "scale": "\(scaleFactor)x", "size": "\(size)x\(size)"])
        }
    }

    let contents: [String: Any] = ["images": manifest,
                                   "info": ["author": "xcode", "version": 1]]
    if let data = try? JSONSerialization.data(withJSONObject: contents,
                                              options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: appIconSet.appendingPathComponent("Contents.json"))
    }
    print("AppIcon: \(manifest.count) boyut")

    for (name, pixels) in [("logo.png", 256), ("logo@2x.png", 512)] {
        guard let data = render(Icon(padded: false), pixels: pixels) else { continue }
        try? data.write(to: logoSet.appendingPathComponent(name))
    }
    print("Logo: 2 boyut")
}
