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
        
        // Soporte real de vibración para iPhone 6 / 6 Plus (motor ERM / chip Apple A8)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    static func playSuccess() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
}
