import Carbon.HIToolbox
import Foundation

/// Sistem geneli kısayol (⌘⇧V). Carbon `RegisterEventHotKey`, accessibility izni
/// istemeyen tek güvenilir sistem geneli kısayol API'si olduğu için tercih edildi.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private let id: UInt32
    private var ref: EventHotKeyRef?

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotKey.installDispatcherIfNeeded()

        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x50_43_4C_50), id: id) // 'PCLP'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)

        guard status == noErr, ref != nil else {
            HotKey.handlers[id] = nil
            NSLog("PureClip: kısayol kaydedilemedi (OSStatus \(status))")
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.handlers[id] = nil
    }

    private static func installDispatcherIfNeeded() {
        guard eventHandler == nil else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr else { return status }

            if let handler = HotKey.handlers[hotKeyID.id] {
                DispatchQueue.main.async(execute: handler)
            }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}

/// Carbon sanal tuş kodları — Carbon import'u bu dosyada kalsın diye burada sarmalanıyor.
enum KeyCode {
    static let v = UInt32(kVK_ANSI_V)

    /// 1-5 tuşları — sabitlenmiş öğe slotları için.
    static let digits: [UInt32] = [
        UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3),
        UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5)
    ]
}

enum KeyModifier {
    static let command = UInt32(cmdKey)
    static let shift = UInt32(shiftKey)
    static let option = UInt32(optionKey)
    static let control = UInt32(controlKey)
}
