import UIKit

struct Theme {
    struct Colors {
        // Fondos (Tema Oscuro Elegante — idéntico a la guía visual de Google TV)
        static let background = UIColor(red: 31/255, green: 34/255, blue: 42/255, alpha: 1.0)       // #1F222A
        static let surface = UIColor(red: 40/255, green: 43/255, blue: 53/255, alpha: 1.0)          // #282B35
        static let surfacePressed = UIColor(red: 54/255, green: 59/255, blue: 72/255, alpha: 1.0)   // #363B48
        
        // Bordes y separadores sutiles
        static let border = UIColor(red: 50/255, green: 54/255, blue: 66/255, alpha: 0.6)
        static let divider = UIColor(red: 56/255, green: 60/255, blue: 74/255, alpha: 0.8)
        
        // D-Pad específico
        static let dpadOuter = UIColor(red: 38/255, green: 41/255, blue: 50/255, alpha: 1.0)        // #262932
        static let dpadCenter = UIColor(red: 31/255, green: 33/255, blue: 41/255, alpha: 1.0)       // #1F2129
        
        // Texto e Iconografía
        static let textPrimary = UIColor(white: 1.0, alpha: 1.0)                                    // Blanco puro
        static let textSecondary = UIColor(red: 142/255, green: 149/255, blue: 165/255, alpha: 1.0)// #8E95A5
        static let iconDark = UIColor(white: 1.0, alpha: 0.90)                                      // Blanco para íconos
        
        // Acentos de estado
        static let power = UIColor(red: 105/255, green: 219/255, blue: 124/255, alpha: 1.0)        // #69DB7C Verde botón Power
        static let connected = UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)      // #34C759 Verde estado
        static let disconnected = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)// Gris
        static let accent = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0)        // Azul
    }
    
    struct Shadows {
        static func applySoftCard(to layer: CALayer) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 12
            layer.shadowOpacity = 0.35
        }
        
        static func applyButtonShadow(to layer: CALayer) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 6
            layer.shadowOpacity = 0.30
        }
    }
}
