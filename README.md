# 💎 PureClip

**PureClip**, macOS için özel olarak tasarlanmış, premium ve modern bir pano (clipboard) yöneticisidir. Sadece kopyaladıklarınızı saklamakla kalmaz, aynı zamanda sistem ekran görüntülerini de otomatik olarak organize eder.

![PureClip](native/PureClip/Assets.xcassets/Logo.imageset/logo%402x.png)

## ✨ Özellikler

- 🖼️ **Metin ve Resim Desteği**: Kopyaladığınız her şeyi (zengin metinler, kodlar, resimler) anında yakalar.
- 📸 **Akıllı Ekran Görüntüsü Yönetimi**: `Cmd + Shift + 3/4` ile aldığınız ekran görüntülerini anında PureClip'e ekler. İsterseniz yakalanan dosyayı masaüstünden çöpe taşır (varsayılan olarak kapalı).
- ⌘ **Hızlı Erişim**: `Cmd + Shift + V` (veya sizin belirlediğiniz) kısayolu ile istediğiniz an karşınıza çıkar.
- ☁️ **Native Materyal**: Panel, sistem menülerinin kullandığı cam materyali çıplak kullanır; açık/koyu tema ve macOS 26'daki Liquid Glass işlemesi sistemden gelir.
- 🎨 **Uyarlanabilir İkon**: Icon Composer katmanlı ikonu sayesinde açık, koyu, şeffaf ve tonlanmış görünümlere sistem tarafından uyarlanır.
- 📌 **Sabitleme**: Sık kullandığınız öğeleri listenin en başında tutun.
- 🔍 **Anında Arama**: Geçmişinizde saniyeler içinde arama yapın.
- 🗂️ **Kategori ve Sıralama**: Tümü / Metin / Görsel sekmeleri ve En Yeni · En Eski · A-Z sıralaması ile yüzlerce kayıt arasında hızlı gezinin.
- ⚡ **Otomatik Yapıştır**: Seçtiğiniz öğeyi öndeki uygulamaya anında yapıştırır (erişilebilirlik izni gerekir).
- 🔊 **Sesli Geri Bildirim**: Bir öğe kopyalandığında veya yakalandığında zarif bir sistem sesiyle sizi bilgilendirir.

## 🛠️ Derleme

Gereksinim: **Xcode 26+** (Icon Composer ikonu ve `NSGlassEffectView` macOS 26 SDK'sı
ister), çalışma için macOS 14 (Sonoma) veya üzeri. Harici bağımlılık yok.

```bash
git clone https://github.com/cengo14/pureclip.git
cd pureclip/native
open PureClip.xcodeproj
```

Komut satırından:
```bash
xcodebuild -project native/PureClip.xcodeproj -scheme PureClip -configuration Release build
```

Geliştirme bayrakları: `--show-panel` paneli açık başlatır, `--appearance dark|light`
sistem temasından bağımsız olarak görünümü zorlar.

## 🚀 Teknolojiler

- **Swift + SwiftUI**: Yerel arayüz ve uygulama iskeleti.
- **AppKit**: `NSStatusItem` menü çubuğu öğesi, odağı çalmayan `NSPanel`.
- **SQLite (`libsqlite3`)**: Sistemle gelen kitaplık, harici bağımlılık yok.
- **ImageIO**: Resimler diskte saklanır, küçük resimler tam boyut belleğe açılmadan üretilir.
- **SF Symbols**: Sistem ikon seti.

## ⚡ Performans

Sürüm 2.0 ile uygulama Electron'dan native Swift/SwiftUI'a taşındı. Aynı makinede,
aynı yöntemle (`footprint -p`) ve aynı 24 kayıtlık geçmişle ölçülen değerler:

| | v1.x (Electron) | v2.0 (Native) |
|---|---|---|
| Bellek | 224 MB (4 process) | **22 MB** (tek process) |
| Uygulama paketi | 274 MB | **3.7 MB** |
| Geçmiş verisi | 80 MB | **4.5 MB** |

Farkın kaynağı yalnızca Electron'un taban maliyeti değil; resimler artık base64
data URL olarak veritabanına yazılmıyor, pano içeriği `NSPasteboard.changeCount`
ile izleniyor (yarım saniyede bir yeniden kodlanmıyor) ve tekrar eden girdiler
indeksli bir hash kolonundan yakalanıyor.

> Not: v2.0 geçmişi sıfırdan başlatır. Electron sürümünün verisi
> `~/Library/Application Support/PureClip/history.db` dosyasında el değmeden durur.

---
Created by **cengodev** - [cengodev.com](https://www.cengodev.com)
Designed for macOS
