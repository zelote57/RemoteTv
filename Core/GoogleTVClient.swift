// GoogleTVClient.swift — Orquestador principal
// Coordina Discovery → Pairing (puerto 6467) → Remote (puerto 6466)

import Foundation

protocol GoogleTVClientDelegate: AnyObject {
    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus)
}

class GoogleTVClient: GoogleTVDiscoveryDelegate, PairingServiceDelegate, RemoteServiceDelegate {

    static let shared = GoogleTVClient()

    weak var delegate: GoogleTVClientDelegate?

    private(set) var currentStatus: ConnectionStatus = .searching {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.clientDidChangeStatus(self, status: self.currentStatus)
            }
        }
    }

    private(set) var currentTVName: String?
    private(set) var currentHost: String?

    private let pairingService = PairingService()
    private let remoteService  = RemoteService()

    // MARK: - Init

    init() {
        self.currentTVName = UserDefaults.standard.string(forKey: "saved_tv_name")
        self.currentHost   = UserDefaults.standard.string(forKey: "saved_tv_ip")

        pairingService.delegate = self
        remoteService.delegate  = self
        GoogleTVDiscovery.shared.delegate = self
    }

    // MARK: - Discovery

    func startAutoDiscovery() {
        if let savedName = currentTVName {
            // Mostramos la TV conocida de inmediato
            currentStatus = .ready(savedName)
        } else {
            currentStatus = .searching
        }
        GoogleTVDiscovery.shared.startDiscovery()
    }

    // MARK: - GoogleTVDiscoveryDelegate

    func discoveryDidUpdateDevices(_ discovery: GoogleTVDiscovery, devices: [DiscoveredTV]) {
        guard let first = devices.first else { return }

        // Actualizamos la TV detectada sin importar el estado anterior
        currentTVName = first.name
        currentHost   = first.host

        // Solo salimos de "searching" si no estamos ya conectados/emparejando
        switch currentStatus {
        case .searching, .disconnected:
            currentStatus = .ready(first.name)
            print("[Client] TV detectada: \(first.name) @ \(first.host)")
        default:
            break
        }
    }

    // MARK: - Conexión / Emparejamiento

    func connect(to tv: DiscoveredTV) {
        currentTVName = tv.name
        currentHost   = tv.host

        UserDefaults.standard.set(tv.name, forKey: "saved_tv_name")
        UserDefaults.standard.set(tv.host, forKey: "saved_tv_ip")

        currentStatus = .connecting(tv.name)
        print("[Client] Iniciando conexión con \(tv.name) (\(tv.host))…")

        let isPaired = UserDefaults.standard.bool(forKey: "tv_paired_\(tv.host)")
        if isPaired {
            // Ya emparejado → conectar directo al canal de control (puerto 6466)
            remoteService.connect(host: tv.host)
        } else {
            // Primera vez → pairing por puerto 6467 (Polo v2)
            pairingService.startPairing(host: tv.host, port: Int(GoogleTVPorts.pairing))
        }
    }

    func submitPin(_ pin: String) {
        pairingService.submitPin(pin)
    }

    // MARK: - PairingServiceDelegate

    func pairingDidRequestPin() {
        guard let name = currentTVName else { return }
        currentStatus = .pairingRequired(name)
        print("[Client] PIN solicitado para \(name)")
    }

    func pairingDidSucceed() {
        guard let host = currentHost, let name = currentTVName else { return }
        print("[Client] Emparejamiento exitoso con \(name)")
        UserDefaults.standard.set(true, forKey: "tv_paired_\(host)")
        HapticManager.playSuccess()
        pairingService.close()
        // Ahora conectamos al canal de control
        remoteService.connect(host: host)
    }

    func pairingDidFail(error: String) {
        print("[Client] Fallo en emparejamiento: \(error)")
        currentStatus = .error("Pairing: \(error)")
    }

    // MARK: - RemoteServiceDelegate

    func remoteServiceDidConnect() {
        guard let name = currentTVName else { return }
        currentStatus = .connected(name)
        print("[Client] Canal de control activo — \(name)")
    }

    func remoteServiceDidDisconnect(error: String?) {
        if let err = error {
            currentStatus = .error(err)
        } else {
            if let name = currentTVName {
                currentStatus = .ready(name)
            } else {
                currentStatus = .disconnected
            }
        }
    }

    // MARK: - Envío de Teclas

    func sendKey(_ key: AndroidKeyCode) {
        switch currentStatus {
        case .connected:
            remoteService.sendKey(key)

        case .ready(let name):
            // Primer toque → conectar
            if let host = currentHost {
                connect(to: DiscoveredTV(name: name, host: host, port: GoogleTVPorts.pairing))
            }

        default:
            print("[Client] No conectado. Estado: \(currentStatus). Tecla ignorada: \(key)")
        }
    }

    func disconnect() {
        remoteService.disconnect()
        pairingService.close()
        currentStatus = .disconnected
    }
}
