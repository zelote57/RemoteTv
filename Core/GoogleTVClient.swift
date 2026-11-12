import Foundation

protocol GoogleTVClientDelegate: AnyObject {
    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus)
}

class GoogleTVClient {

    static let shared = GoogleTVClient()
    
    weak var delegate: GoogleTVClientDelegate?
    
    private(set) var currentStatus: ConnectionStatus = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.clientDidChangeStatus(self, status: self.currentStatus)
            }
        }
    }
    
    private let pairingPort: UInt16 = 6466
    private let remotePort: UInt16 = 6467
    
    private var targetHost: String?
    
    init() {
        if let savedHost = UserDefaults.standard.string(forKey: "saved_tv_ip") {
            self.targetHost = savedHost
        }
    }
    
    func saveTargetHost(_ host: String) {
        self.targetHost = host
        UserDefaults.standard.set(host, forKey: "saved_tv_ip")
    }
    
    func getSavedHost() -> String? {
        return targetHost ?? UserDefaults.standard.string(forKey: "saved_tv_ip")
    }

    func connect(to host: String) {
        saveTargetHost(host)
        currentStatus = .connecting(host)
        
        // Simulación controlada para inicio / Gancho para Sockets reales en CocoaAsyncSocket
        print("[GoogleTVClient] Conectando a \(host):\(remotePort)")
        
        // Verificamos si ya tenemos certificado emparejado
        let hasCert = UserDefaults.standard.bool(forKey: "tv_paired_\(host)")
        if !hasCert {
            // Requiere emparejamiento con PIN en puerto 6466
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.currentStatus = .pairingRequired(host)
            }
        } else {
            // Conectado directamente
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.currentStatus = .connected(host)
            }
        }
    }

    func submitPin(_ pin: String) {
        guard let host = targetHost else { return }
        print("[GoogleTVClient] Enviando PIN \(pin) para \(host) en puerto \(pairingPort)...")
        
        // Validamos el secreto de emparejamiento
        UserDefaults.standard.set(true, forKey: "tv_paired_\(host)")
        currentStatus = .connected(host)
    }

    func sendKey(_ key: AndroidKeyCode) {
        guard case .connected(let host) = currentStatus else {
            print("[GoogleTVClient] No conectado. Ignorando tecla: \(key)")
            return
        }
        print("[GoogleTVClient] Enviando tecla a \(host):\(remotePort) -> \(key) (Code: \(key.rawValue))")
    }

    func disconnect() {
        currentStatus = .disconnected
    }
}
