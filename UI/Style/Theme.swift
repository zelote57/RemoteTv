import UIKit

struct Theme {
    struct Colors {
        // Fondos
        static let background = UIColor(red: 246/255, green: 247/255, blue: 250/255, alpha: 1.0) // Blanco perla muy suave
        static let surface = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)    // Blanco puro
        static let surfacePressed = UIColor(red: 238/255, green: 240/255, blue: 244/255, alpha: 1.0)
        
        // Bordes y separadores sutiles
        static let border = UIColor(red: 226/255, green: 230/255, blue: 236/255, alpha: 1.0)
        static let divider = UIColor(red: 235/255, green: 238/255, blue: 242/255, alpha: 1.0)
        
        // Texto e Iconografía
        static let iconDark = UIColor(red: 33/255, green: 37/255, blue: 41/255, alpha: 1.0)     // Antracita casi negro
        static let textPrimary = UIColor(red: 30/255, green: 34/255, blue: 39/255, alpha: 1.0)
        static let textSecondary = UIColor(red: 120/255, green: 130/255, blue: 145/255, alpha: 1.0)
        
        // Acentos de estado
        static let power = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)       // Rojo suave para encendido
        static let connected = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0)   // Verde estado
        static let disconnected = UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1.0)
        static let accent = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)     // Azul iOS
    }
    
    struct Shadows {
        static func applySoftCard(to layer: CALayer) {
            layer.shadowColor = UIColor(red: 20/255, green: 30/255, blue: 50/255, alpha: 0.07).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 12
            layer.shadowOpacity = 1.0
        }
        
        static func applyButtonShadow(to layer: CALayer) {
            layer.shadowColor = UIColor(red: 20/255, green: 30/255, blue: 50/255, alpha: 0.05).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 8
            layer.shadowOpacity = 1.0
        }
    }
}
