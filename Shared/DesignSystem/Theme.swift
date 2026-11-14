// Theme.swift — Centralized design system theme definitions for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+ (Faithfully matches Stitch design)

import UIKit

/// Supported visual appearance modes across the application.
enum AppThemeMode: String {
    case dark
    case light
}

/// Central design system providing semantic colors, shadows, and appearance management.
struct Theme {

    /// Broadcast notification dispatched whenever the active theme mode changes.
    static let themeDidChangeNotification = Notification.Name("AppThemeDidChangeNotification")

    /// Active theme appearance mode stored in user preferences.
    static var currentMode: AppThemeMode {
        get {
            let saved = UserDefaults.standard.string(forKey: AppConstants.StorageKeys.appThemeMode) ?? AppThemeMode.dark.rawValue
            return AppThemeMode(rawValue: saved) ?? .dark
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: AppConstants.StorageKeys.appThemeMode)
            NotificationCenter.default.post(name: themeDidChangeNotification, object: nil)
        }
    }

    /// Convenience flag indicating whether the dark appearance is active.
    static var isDark: Bool {
        return currentMode == .dark
    }

    /// Toggles the active theme between dark and light modes.
    static func toggleTheme() {
        currentMode = isDark ? .light : .dark
    }

    // MARK: - Semantic Colors
    struct Colors {
        
        /// Root view controller and canvas background color
        static var background: UIColor {
            return Theme.isDark
                ? UIColor(red: 28/255, green: 32/255, blue: 42/255, alpha: 1.0)       // #1C202A (Dark)
                : UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1.0)    // #F8FAFC (Light Slate 50)
        }

        /// Surface background for cards, sheets, and circular buttons
        static var surface: UIColor {
            return Theme.isDark
                ? UIColor(red: 37/255, green: 43/255, blue: 58/255, alpha: 1.0)       // #252B3A
                : UIColor(red: 237/255, green: 242/255, blue: 247/255, alpha: 1.0)    // #EDF2F7
        }

        /// Highlighted state background color for interactive elements
        static var surfacePressed: UIColor {
            return Theme.isDark
                ? UIColor(red: 30/255, green: 35/255, blue: 48/255, alpha: 1.0)       // #1E2330
                : UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0)    // #E2E8F0
        }

        /// Outline border color for controls and cards
        static var border: UIColor {
            return Theme.isDark
                ? UIColor(white: 1.0, alpha: 0.05)                                    // rgba(255, 255, 255, 0.05)
                : UIColor.white                                                       // #FFFFFF (Crisp white border in Light)
        }

        /// Subtle separator line color
        static var divider: UIColor {
            return Theme.isDark
                ? UIColor(white: 1.0, alpha: 0.10)
                : UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 1.0)   // #CBD5E1 (Slate 300)
        }

        /// D-Pad outer ring background color
        static var dpadOuter: UIColor {
            return Theme.isDark
                ? UIColor(red: 36/255, green: 43/255, blue: 58/255, alpha: 1.0)       // #242B3A
                : UIColor(red: 233/255, green: 238/255, blue: 244/255, alpha: 1.0)    // #E9EEF4
        }

        /// D-Pad center OK button background color
        static var dpadCenter: UIColor {
            return Theme.isDark
                ? UIColor(red: 27/255, green: 32/255, blue: 44/255, alpha: 1.0)       // #1B202C
                : UIColor(red: 243/255, green: 246/255, blue: 249/255, alpha: 1.0)    // #F3F6F9
        }

        /// High contrast primary label and icon tint color
        static var textPrimary: UIColor {
            return Theme.isDark
                ? UIColor(white: 1.0, alpha: 0.95)
                : UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)       // #0F172A (Slate 900)
        }

        /// Medium contrast secondary label, D-Pad arrows, and icon tint
        static var textSecondary: UIColor {
            return Theme.isDark
                ? UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1.0)   // #9CA3AF (Gray 400)
                : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)   // #64748B (Slate 500)
        }

        // MARK: - Accent & Action Colors
        
        /// Vibrant power button background color
        static var power: UIColor {
            return Theme.isDark
                ? UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)     // #34C759 iOS green
                : UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)    // #10B981 Emerald
        }
        
        /// Power button gradient top (Dark mode)
        static let powerGradientTop = UIColor(red: 62/255, green: 219/255, blue: 87/255, alpha: 1.0)    // #3EDB57
        
        /// Power button gradient bottom (Dark mode)
        static let powerGradientBottom = UIColor(red: 46/255, green: 179/255, blue: 70/255, alpha: 1.0)  // #2EB346

        /// Sun icon amber color
        static var sunYellow: UIColor {
            return Theme.isDark
                ? UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0)    // #FBBF24 (Amber 400)
                : UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)    // #F59E0B (Amber 500)
        }

        /// Connection status indicator dot and label
        static var connected: UIColor {
            return Theme.isDark
                ? UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)     // #34C759
                : UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)    // #10B981
        }
        
        /// Disconnected status color
        static var disconnected: UIColor {
            return Theme.isDark
                ? UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)   // #6B7280
                : UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)   // #94A3B8
        }
        
        static let error = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        static let accent = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0)
    }

    // MARK: - Layer Shadows (Neomorphic Depth)
    struct Shadows {
        
        /// Standard circular action button shadow
        static func applyButtonShadow(to layer: CALayer) {
            let isDark = Theme.isDark
            layer.shadowColor = (isDark ? UIColor.black : UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 6)
            layer.shadowRadius = isDark ? 8 : 7
            layer.shadowOpacity = isDark ? 0.45 : 0.25
        }

        /// Power button distinctive glow shadow
        static func applyPowerShadow(to layer: CALayer) {
            let isDark = Theme.isDark
            layer.shadowColor = (isDark ? UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0) : UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)).cgColor
            layer.shadowOffset = CGSize(width: 0, height: isDark ? 6 : 8)
            layer.shadowRadius = isDark ? 8 : 9
            layer.shadowOpacity = 0.40
        }

        /// D-Pad outer disc elevation shadow
        static func applyDpadOuterShadow(to layer: CALayer) {
            let isDark = Theme.isDark
            layer.shadowColor = (isDark ? UIColor.black : UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 16)
            layer.shadowRadius = 18
            layer.shadowOpacity = isDark ? 0.50 : 0.35
        }

        /// D-Pad center OK button depth shadow
        static func applyDpadCenterShadow(to layer: CALayer) {
            let isDark = Theme.isDark
            layer.shadowColor = (isDark ? UIColor.black : UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)).cgColor
            layer.shadowOffset = CGSize(width: 0, height: isDark ? 8 : 6)
            layer.shadowRadius = isDark ? 12 : 8
            layer.shadowOpacity = isDark ? 0.60 : 0.35
        }

        /// Soft card/sheet shadow
        static func applySoftCard(to layer: CALayer) {
            applyButtonShadow(to: layer)
        }
    }
}
