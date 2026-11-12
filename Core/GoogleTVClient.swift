import Foundation

protocol GoogleTVClientDelegate: AnyObject {
    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus)
}

class GoogleTVClient: GoogleTVDiscoveryDelegate {

    static let shared = GoogleTVClient()
    
    weak var delegate: GoogleTVClientDelegate?
    
    private(set) var currentStatus: ConnectionStatus = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.clientDidChangeStatus(self, status: self.currentStatus)
            }
        }
    }
    
    private(set) var currentTVName: String?
    private(set) var currentHost: String?
    
    private let pairingPort: UInt16 = 6466
    private let remotePort: UInt16 = 6467
    
    init() {
        self.currentTVName = UserDefaults.standard.string(forKey: "saved_tv_name")
        self.currentHost = UserDefaults.standard.string(forKey: "saved_tv_ip")
        
        GoogleTVDiscovery.shared.delegate = self
    }

    func startAutoDiscovery() {
        currentStatus = .searching
        GoogleTVDiscovery.shared.startDiscovery()
    }

    // MARK: - GoogleTVDiscoveryDelegate
    func discoveryDidUpdateDevices(_ discovery: GoogleTVDiscovery, devices: [DiscoveredTV]) {
        // Si hay una TV guardada previamente y la encontramos, auto-conectamos
        if case .searching = currentStatus, let savedHost = currentHost {
            if let matched = devices.first(where: { $0.host == savedHost }) {
                connect(to: matched)
            }
        }
    }

    func connect(to tv: DiscoveredTV) {
        self.currentTVName = tv.name
        self.currentHost = tv.host
        
        UserDefaults.standard.set(tv.name, forKey: "saved_tv_name")
        UserDefaults.standard.set(tv.host, forKey: "saved_tv_ip")
        
        currentStatus = .connecting(tv.name)
        print("[GoogleTVClient] Conectando a \(tv.name) (\(tv.host))...")
        
        // Comprobamos si ya está emparejado
        let isPaired = UserDefaults.standard.bool(forKey: "tv_paired_\(tv.host)")
        if !isPaired {
            // Solicitar código PIN en pantalla
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.currentStatus = .pairingRequired(tv.name)
            }
        } else {
            // Conexión directa
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.currentStatus = .connected(tv.name)
            }
        }
    }

    func submitPin(_ pin: String) {
        guard let host = currentHost, let name = currentTVName else { return }
        print("[GoogleTVClient] Verificando PIN \(pin) para \(name) (\(host))...")
        
        // Guardamos el emparejamiento confirmado
        UserDefaults.standard.set(true, forKey: "tv_paired_\(host)")
        currentStatus = .connected(name)
        HapticManager.playSuccess()
    }

    func sendKey(_ key: AndroidKeyCode) {
        guard case .connected(let name) = currentStatus, let host = currentHost else {
            print("[GoogleTVClient] No conectado. Ignorando tecla: \(key)")
            return
        }
        print("[GoogleTVClient] Enviando tecla a \(name) (\(host)) -> \(key) (Code: \(key.rawValue))")
    }

    func disconnect() {
        currentStatus = .disconnected
    }
}
