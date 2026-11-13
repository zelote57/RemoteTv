import UIKit

enum AppThemeMode: String {
    case dark
    case light
}

struct Theme {

    static var currentMode: AppThemeMode {
        get {
            let saved = UserDefaults.standard.string(forKey: "app_theme_mode") ?? "dark"
            return AppThemeMode(rawValue: saved) ?? .dark
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "app_theme_mode")
        }
    }

    static var isDark: Bool {
        return currentMode == .dark
    }

    static func toggleTheme() {
        currentMode = isDark ? .light : .dark
    }

    struct Colors {
        // Fondos
        static var background: UIColor {
            return Theme.isDark
                ? UIColor(red: 31/255, green: 34/255, blue: 42/255, alpha: 1.0)       // #1F222A (Oscuro)
                : UIColor(red: 246/255, green: 247/255, blue: 250/255, alpha: 1.0)    // #F6F7FA (Claro)
        }

        // Superficie de botones / tarjetas
        static var surface: UIColor {
            return Theme.isDark
                ? UIColor(red: 40/255, green: 43/255, blue: 53/255, alpha: 1.0)       // #282B35
                : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)    // #FFFFFF
        }

        static var surfacePressed: UIColor {
            return Theme.isDark
                ? UIColor(red: 54/255, green: 59/255, blue: 72/255, alpha: 1.0)       // #363B48
                : UIColor(red: 236/255, green: 239/255, blue: 245/255, alpha: 1.0)    // #ECEFF5
        }

        // Bordes y separadores
        static var border: UIColor {
            return Theme.isDark
                ? UIColor(red: 50/255, green: 54/255, blue: 66/255, alpha: 0.6)
                : UIColor(red: 226/255, green: 230/255, blue: 236/255, alpha: 1.0)
        }

        static var divider: UIColor {
            return Theme.isDark
                ? UIColor(red: 56/255, green: 60/255, blue: 74/255, alpha: 0.8)
                : UIColor(red: 235/255, green: 238/255, blue: 242/255, alpha: 1.0)
        }

        // D-Pad específico
        static var dpadOuter: UIColor {
            return Theme.isDark
                ? UIColor(red: 38/255, green: 41/255, blue: 50/255, alpha: 1.0)       // #262932
                : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)    // #FFFFFF
        }

        static var dpadCenter: UIColor {
            return Theme.isDark
                ? UIColor(red: 31/255, green: 33/255, blue: 41/255, alpha: 1.0)       // #1F2129
                : UIColor(red: 240/255, green: 242/255, blue: 247/255, alpha: 1.0)    // #F0F2F7
        }

        // Texto e Iconografía
        static var textPrimary: UIColor {
            return Theme.isDark
                ? UIColor(white: 1.0, alpha: 1.0)                                     // Blanco
                : UIColor(red: 30/255, green: 34/255, blue: 39/255, alpha: 1.0)       // Antracita
        }

        static var textSecondary: UIColor {
            return Theme.isDark
                ? UIColor(red: 142/255, green: 149/255, blue: 165/255, alpha: 1.0)   // #8E95A5
                : UIColor(red: 120/255, green: 130/255, blue: 145/255, alpha: 1.0)   // #788291
        }

        // Acentos de estado
        static let power = UIColor(red: 105/255, green: 219/255, blue: 124/255, alpha: 1.0)   // #69DB7C Verde
        static let connected = UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0) // #34C759 Verde
        static let disconnected = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)
        static let accent = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0)   // Azul
    }

    struct Shadows {
        static func applySoftCard(to layer: CALayer) {
            let isDark = Theme.isDark
            layer.shadowColor = (isDark ? UIColor.black : UIColor(red: 20/255, green: 30/255, blue: 50/255, alpha: 1.0)).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = isDark ? 12 : 10
            layer.shadowOpacity = isDark ? 0.35 : 0.08
        }

        static func applyButtonShadow(to layer: CALayer) {
            let isDark = Theme.isDark
            layer.shadowColor = (isDark ? UIColor.black : UIColor(red: 20/255, green: 30/255, blue: 50/255, alpha: 1.0)).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = isDark ? 6 : 6
            layer.shadowOpacity = isDark ? 0.30 : 0.06
        }
    }
}
