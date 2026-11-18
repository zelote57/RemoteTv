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
        AudioServicesPlaySystemSound(1104)
    }

    /// Triggers feedback pattern upon successful device connection or pairing.
    static func playSuccess() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    /// Triggers subtle selection feedback pattern for pickers and list items.
    static func playSelection() {
        if #available(iOS 10.0, *) {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
        AudioServicesPlaySystemSound(1104)
    }
    
    /// Triggers alert feedback pattern when an operation fails.
    static func playError() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}
