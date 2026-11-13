// HapticManager.swift — Haptic and auditory tactile feedback manager for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+ (optimized for iPhone 6 Plus)

import UIKit
import AudioToolbox

/// Manages tactile haptic impulses and subtle auditory feedback across physical interactions.
struct HapticManager {
    
    /// Triggers a subtle tactile tap on button press.
    /// Employs UIImpactFeedbackGenerator on devices with Taptic Engine,
    /// and falls back to system audio click (ID 1104) on older devices like iPhone 6 Plus.
    static func playTactileClick() {
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        
        // Native iOS keyboard tactile click sound ID 1104
        // Provides instant physical-like feedback without the excessive rattle of vibration 4095
        AudioServicesPlaySystemSound(1104)
    }

    /// Triggers a celebratory feedback pattern upon successful device connection or pairing.
    static func playSuccess() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        
        // Single standard physical pulse for confirmation
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    /// Triggers an alert feedback pattern when an operation fails.
    static func playError() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}
