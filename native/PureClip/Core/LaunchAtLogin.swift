import ServiceManagement

/// `app.setLoginItemSettings` karşılığı. macOS 13+ `SMAppService`, kullanıcının
/// Sistem Ayarları > Genel > Giriş Öğeleri listesinde görüp yönetebildiği modern API.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("PureClip: giriş öğesi güncellenemedi — \(error.localizedDescription)")
        }
        return isEnabled
    }
}
