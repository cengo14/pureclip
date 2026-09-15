import Foundation

/// Ayarlar artık veritabanında değil `UserDefaults`'ta. Electron sürümündeki
/// `settings` tablosu her okumada bir SQL sorgusu demekti; burada bunlar bellekten
/// okunuyor ve sistem tarafından kalıcılaştırılıyor.
enum SettingsKey {
    static let historyLimit = "historyLimit"
    static let autoCleanupDays = "autoCleanupDays"
    static let pasteAsPlainText = "pasteAsPlainText"
    static let soundEnabled = "soundEnabled"
    static let autoPaste = "autoPaste"
    static let watchScreenshots = "watchScreenshots"
    static let deleteScreenshotAfterCapture = "deleteScreenshotAfterCapture"
    static let sortOrder = "sortOrder"
    static let pinnedShortcutsEnabled = "pinnedShortcutsEnabled"
    static let pinnedShortcutModifier = "pinnedShortcutModifier"
}

enum AppSettings {
    /// Electron sürümünün varsayılanlarıyla aynı; tek fark
    /// `deleteScreenshotAfterCapture`: eskiden kullanıcının masaüstündeki dosya
    /// sorulmadan siliniyordu, artık varsayılan olarak kapalı.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.historyLimit: 100,
            SettingsKey.autoCleanupDays: 7,
            SettingsKey.pasteAsPlainText: false,
            SettingsKey.soundEnabled: true,
            SettingsKey.autoPaste: true,
            SettingsKey.watchScreenshots: true,
            SettingsKey.deleteScreenshotAfterCapture: false,
            SettingsKey.pinnedShortcutsEnabled: true,
            SettingsKey.pinnedShortcutModifier: PinnedShortcutModifier.commandShift.rawValue
        ])
    }

    static var historyLimit: Int { UserDefaults.standard.integer(forKey: SettingsKey.historyLimit) }
    static var autoCleanupDays: Int { UserDefaults.standard.integer(forKey: SettingsKey.autoCleanupDays) }
    static var pasteAsPlainText: Bool { UserDefaults.standard.bool(forKey: SettingsKey.pasteAsPlainText) }
    static var soundEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.soundEnabled) }
    static var autoPaste: Bool { UserDefaults.standard.bool(forKey: SettingsKey.autoPaste) }
    static var watchScreenshots: Bool { UserDefaults.standard.bool(forKey: SettingsKey.watchScreenshots) }
    static var deleteScreenshotAfterCapture: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.deleteScreenshotAfterCapture)
    }

    static var pinnedShortcutsEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.pinnedShortcutsEnabled)
    }

    static var pinnedShortcutModifier: PinnedShortcutModifier {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.pinnedShortcutModifier) ?? ""
        return PinnedShortcutModifier(rawValue: raw) ?? .commandShift
    }
}

/// Sabitlenmiş öğe kısayollarının değiştirici kombinasyonu.
///
/// Global kısayol kaydetmek o tuşları bütün uygulamalardan alır; ⌘⇧1-5 birçok
/// uygulamada kullanıldığı için kullanıcının başka bir kombinasyona geçebilmesi
/// gerekiyor. Rakamlar (1-5) sabit.
enum PinnedShortcutModifier: String, CaseIterable, Identifiable {
    case commandShift
    case controlOption
    case commandControl
    case optionShift

    var id: String { rawValue }

    /// Carbon `RegisterEventHotKey` için değiştirici maskesi.
    var carbonMask: UInt32 {
        switch self {
        case .commandShift:   return KeyModifier.command | KeyModifier.shift
        case .controlOption:  return KeyModifier.control | KeyModifier.option
        case .commandControl: return KeyModifier.command | KeyModifier.control
        case .optionShift:    return KeyModifier.option | KeyModifier.shift
        }
    }

    /// Arayüzde gösterilen simgeler, ör. "⌘⇧".
    var symbols: String {
        switch self {
        case .commandShift:   return "⌘⇧"
        case .controlOption:  return "⌃⌥"
        case .commandControl: return "⌘⌃"
        case .optionShift:    return "⌥⇧"
        }
    }

    /// Belirli bir slot için tam kısayol metni, ör. "⌘⇧1".
    func label(slot: Int) -> String {
        "\(symbols)\(slot)"
    }
}
