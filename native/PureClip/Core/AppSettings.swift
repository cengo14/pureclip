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
            SettingsKey.deleteScreenshotAfterCapture: false
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
}
