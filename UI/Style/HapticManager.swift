import UIKit
import AudioToolbox

struct HapticManager {
    static func playTactileClick() {
        // En dispositivos modernos con Taptic Engine (iPhone 7, X, 14 Pro...)
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
        
        // Soporte específico para el motor de vibración del iPhone 6 / 6 Plus (Chip Apple A8)
        // 1519: Peak (Tap suave táctil de iOS)
        AudioServicesPlaySystemSound(1519)
    }

    static func playSuccess() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        AudioServicesPlaySystemSound(1520) // Pop
    }
}
