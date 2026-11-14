import Foundation

struct GoogleTVPorts {
    static let pairing: UInt16 = 6467 // Puerto TLS para emparejamiento / PIN (Polo v2)
    static let remote: UInt16  = 6466 // Puerto TLS para control remoto (KeyEvents)
}

enum AndroidKeyCode: Int {
    case dpadUp = 19
    case dpadDown = 20
    case dpadLeft = 21
    case dpadRight = 22
    case dpadCenter = 23
    
    case back = 4
    case home = 3
    case menu = 82
    case search = 84
    
    case volumeUp = 24
    case volumeDown = 25
    case volumeMute = 164
    
    case power = 26
    case mediaPlayPause = 85
    case mediaNext = 87
    case mediaPrevious = 88
    
    case channelUp = 166
    case channelDown = 167
    case tvInput = 178
    case assistant = 219 // KEYCODE_ASSIST para invocar Google Assistant en la pantalla del TV
}

enum ConnectionStatus: Equatable {
    case disconnected
    case searching
    case discovered(String)      // TV detectada en red, pendiente de acción explícita del usuario
    case connecting(String)      // Iniciando handshake TLS hacia el socket
    case pairingRequired(String) // TV solicita código PIN en pantalla
    case connected(String)       // Canal de control activo, enviando KeyEvents
    case error(String)
}
