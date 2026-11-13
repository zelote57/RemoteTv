import UIKit
import AudioToolbox

struct HapticManager {
    static func playTactileClick() {
        // En dispositivos con Taptic Engine (iPhone 7, X, 14 Pro...)
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        
        // En iPhone 6 / 6 Plus: click táctil sutil del sistema (sonido nativo de teclado iOS 1104)
        // Reemplaza la vibración larga de llamada (4095) que sonaba y vibraba demasiado fuerte
        AudioServicesPlaySystemSound(1104)
    }

    static func playSuccess() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        // Vibración física única al confirmar emparejamiento con éxito
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
}
