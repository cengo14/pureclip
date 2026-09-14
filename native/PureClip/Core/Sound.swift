import AppKit

/// Electron sürümü her kopyalamada `exec('afplay /System/Library/Sounds/Tink.aiff')`
/// ile ayrı bir process açıyordu. Burada ses bir kez yüklenip yeniden çalınıyor.
enum Sound {
    static let captured: SoundPlayer = SoundPlayer(path: "/System/Library/Sounds/Tink.aiff")
}

final class SoundPlayer {
    private let sound: NSSound?

    init(path: String) {
        sound = NSSound(contentsOfFile: path, byReference: true)
    }

    func play() {
        guard let sound else { return }
        if sound.isPlaying { sound.stop() } // hızlı art arda kopyalamalarda baştan çal
        sound.play()
    }
}
