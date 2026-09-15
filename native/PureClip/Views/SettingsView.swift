import AppKit
import SwiftUI

struct SettingsView: View {
    let store: HistoryStore

    @AppStorage(SettingsKey.historyLimit) private var historyLimit = 100
    @AppStorage(SettingsKey.autoCleanupDays) private var autoCleanupDays = 7
    @AppStorage(SettingsKey.pasteAsPlainText) private var pasteAsPlainText = false
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = true
    @AppStorage(SettingsKey.autoPaste) private var autoPaste = true
    @AppStorage(SettingsKey.watchScreenshots) private var watchScreenshots = true
    @AppStorage(SettingsKey.deleteScreenshotAfterCapture) private var deleteScreenshot = false
    @AppStorage(SettingsKey.pinnedShortcutsEnabled) private var pinnedShortcutsEnabled = true
    @AppStorage(SettingsKey.pinnedShortcutModifier) private var shortcutModifier = PinnedShortcutModifier.commandShift

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var isAccessible = Paster.isTrusted
    @State private var updateState: UpdateState = .idle
    @State private var confirmingQuit = false
    @State private var pendingUpdate: (version: String, url: URL)?

    private enum UpdateState: Equatable {
        case idle, checking, upToDate, failed
        case available(String)

        var label: String {
            switch self {
            case .idle: return "Güncelleştirmeleri Denetle"
            case .checking: return "Kontrol ediliyor..."
            case .upToDate: return "Uygulama Güncel"
            case .failed: return "Bağlantı Hatası"
            case .available(let version): return "Yeni Sürüm Mevcut: v\(version)"
            }
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                generalSection
                shortcutSection
                pasteSection
                accessibilitySection
                actionsSection
                footer
            }
            .padding(16)
        }
        .scrollIndicators(.never)
        .onAppear {
            // Kullanıcı Sistem Ayarları'ndan izni değiştirmiş olabilir.
            isAccessible = Paster.isTrusted
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        // İzin verildiği anda rozet kendiliğinden güncellensin: kullanıcı Sistem
        // Ayarları'ndan dönünce paneli kapatıp açmak zorunda kalmasın.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !isAccessible else { return }
            isAccessible = Paster.isTrusted
        }
        .confirmationDialog("Uygulamadan tamamen çıkmak istiyor musunuz?",
                            isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("Çık", role: .destructive) { NSApp.terminate(nil) }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog("Yeni bir sürüm bulundu. İndirme sayfasına gitmek ister misiniz?",
                            isPresented: Binding(get: { pendingUpdate != nil },
                                                 set: { if !$0 { pendingUpdate = nil } }),
                            titleVisibility: .visible) {
            Button("İndirme Sayfasını Aç") {
                if let url = pendingUpdate?.url { NSWorkspace.shared.open(url) }
                pendingUpdate = nil
            }
            Button("Vazgeç", role: .cancel) { pendingUpdate = nil }
        }
    }

    // MARK: - Bölümler

    private var generalSection: some View {
        SettingsSection {
            SettingsRow(icon: "power", title: "Otomatik Başlat",
                        description: "Bilgisayar açıldığında başlasın") {
                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { launchAtLogin = LaunchAtLogin.set($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsRow(icon: "number", title: "Geçmiş Sınırı",
                        description: "Saklanacak maksimum öğe sayısı") {
                Picker("", selection: $historyLimit) {
                    ForEach([10, 20, 50, 100], id: \.self) { Text("\($0) Öğe").tag($0) }
                }
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }

            SettingsRow(icon: "calendar", title: "Otomatik Temizleme",
                        description: "Şu süreden eski öğeleri sil") {
                Picker("", selection: $autoCleanupDays) {
                    ForEach([1, 3, 7, 30], id: \.self) { Text("\($0) Gün").tag($0) }
                }
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    private var shortcutSection: some View {
        SettingsSection {
            SettingsRow(icon: "keyboard", title: "Kısayol Atama",
                        description: "Sabitlenmiş öğelere 1-5 arası kısayol ver") {
                switchToggle($pinnedShortcutsEnabled)
            }

            if pinnedShortcutsEnabled {
                SettingsRow(icon: "command", title: "Değiştirici",
                            description: "Başka bir uygulamayla çakışırsa değiştirin") {
                    Picker("", selection: $shortcutModifier) {
                        ForEach(PinnedShortcutModifier.allCases) { option in
                            Text("\(option.symbols) 1-5").tag(option)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                }
            }
        }
    }

    private var pasteSection: some View {
        SettingsSection {
            SettingsRow(icon: "textformat", title: "Düz Metin Olarak Yapıştır",
                        description: "Biçimlendirmeyi temizler") {
                switchToggle($pasteAsPlainText)
            }

            SettingsRow(icon: "speaker.wave.2", title: "Ses Efektleri",
                        description: "Kopyalandığında hafif ses çal") {
                switchToggle($soundEnabled)
            }

            SettingsRow(icon: "bolt", title: "Otomatik Yapıştır",
                        description: "Seçilen öğeyi öndeki uygulamaya yapıştır") {
                switchToggle($autoPaste)
            }

            SettingsRow(icon: "camera.viewfinder", title: "Ekran Görüntülerini Yakala",
                        description: "Masaüstüne kaydedilenleri geçmişe ekle") {
                switchToggle($watchScreenshots)
            }

            if watchScreenshots {
                SettingsRow(icon: "trash", title: "Yakaladıktan Sonra Sil",
                            description: "Ekran görüntüsü dosyasını masaüstünden kaldır") {
                    switchToggle($deleteScreenshot)
                }
            }
        }
    }

    private var accessibilitySection: some View {
        SettingsSection {
            SettingsRow(icon: "checkmark.shield", title: "Erişilebilirlik",
                        description: "Otomatik yapıştırma için gereklidir") {
                Text(isAccessible ? "İzin Verildi" : "İzin Gerekli")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (isAccessible ? Color.green : Theme.pin).opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(isAccessible ? Color.green : Theme.pin)
            }

            if !isAccessible {
                Divider().overlay(Theme.border)
                SettingsButton(icon: "exclamationmark.circle", title: "İzin Ver") {
                    // Önce sistemin kendi dialogu — uygulamayı listeye o ekler.
                    // Dialog daha önce reddedildiyse tekrar görünmez, o yüzden
                    // Sistem Ayarları'nı da açıyoruz.
                    if !Paster.requestTrust() {
                        Paster.openAccessibilitySettings()
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        SettingsSection {
            SettingsButton(icon: "arrow.clockwise",
                           title: updateState.label,
                           isBusy: updateState == .checking) {
                Task { await checkForUpdates() }
            }
            .disabled(updateState == .checking)

            Divider().overlay(Theme.border)

            SettingsButton(icon: "rectangle.portrait.and.arrow.right",
                           title: "Uygulamadan Tamamen Çık",
                           tint: Theme.destructive) {
                confirmingQuit = true
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Kısayol: ⌘ + ⇧ + V")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Theme.accentGlow.opacity(0.25), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 1))
                .padding(.bottom, 24)

            Image("Logo")
                .resizable()
                .frame(width: 64, height: 64)
                .padding(.bottom, 4)

            Text("PureClip")
                .font(.system(size: 20, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(Theme.text)

            Text("Sürüm \(UpdateChecker.currentVersion)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text.opacity(0.5))

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Created by").foregroundStyle(Theme.text)
                    Text("cengodev")
                        .foregroundStyle(Theme.accent)
                        .underline()
                }
                .font(.system(size: 12, weight: .medium))
                .onTapGesture {
                    NSWorkspace.shared.open(URL(string: "https://github.com/cengo14")!)
                }

                Text("Designed for macOS")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.text.opacity(0.3))
            }
            .padding(.top, 24)
        }
        .padding(.top, 8)
    }

    // MARK: - Yardımcılar

    private func switchToggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
    }

    private func checkForUpdates() async {
        updateState = .checking

        switch await UpdateChecker.check() {
        case .upToDate:
            updateState = .upToDate
        case .available(let version, let url):
            updateState = .available(version)
            pendingUpdate = (version, url)
        case .failed:
            updateState = .failed
        }

        try? await Task.sleep(for: .seconds(3))
        updateState = .idle
    }
}

// MARK: - Yeniden kullanılabilir parçalar

/// `.settings-section` — kart, 12 köşe, 0.5 kenarlık, satırlar arası ayırıcı.
struct SettingsSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 0.5)
            )
    }
}

/// `.settings-item`
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().overlay(Theme.border).padding(.leading, 16)
        }
    }
}

/// `.settings-action-button`
struct SettingsButton: View {
    let icon: String
    let title: String
    var tint: Color = Theme.text
    var isBusy = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .rotationEffect(.degrees(isBusy ? 360 : 0))
                    .animation(isBusy ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: isBusy)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isHovering ? Theme.cardBackgroundHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
