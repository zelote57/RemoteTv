import Foundation

enum AndroidKeyCode: Int {
    case dpadUp = 19
    case dpadDown = 20
    case dpadLeft = 21
    case dpadRight = 22
    case dpadCenter = 23
    
    case back = 4
    case home = 3
    case menu = 82
    
    case volumeUp = 24
    case volumeDown = 25
    case volumeMute = 164
    
    case power = 26
    case mediaPlayPause = 85
    case mediaNext = 87
    case mediaPrevious = 88
    
    case channelUp = 166
    case channelDown = 167
}

enum ConnectionStatus: Equatable {
    case disconnected
    case searching
    case connecting(String)      // Nombre de la TV
    case pairingRequired(String) // Nombre de la TV
    case connected(String)       // Nombre de la TV
    case error(String)
}
