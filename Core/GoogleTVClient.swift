// GoogleTVClient.swift — Orquestador principal de la sesión Google TV
// Coordina Discovery → Pairing (puerto 6467) → Remote (puerto 6466)
// Compatible con Swift 5.0 e iOS 12.0+

import Foundation

protocol GoogleTVClientDelegate: AnyObject {
    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus)
}

class GoogleTVClient: GoogleTVDiscoveryDelegate, PairingServiceDelegate, RemoteServiceDelegate {

    static let shared = GoogleTVClient()

    weak var delegate: GoogleTVClientDelegate?

    private(set) var currentStatus: ConnectionStatus = .searching {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
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
        self.currentTVName = UserDefaults.standard.string(forKey: AppConstants.StorageKeys.savedTvName)
        self.currentHost   = UserDefaults.standard.string(forKey: AppConstants.StorageKeys.savedTvHost)

        pairingService.delegate = self
        remoteService.delegate  = self
        GoogleTVDiscovery.shared.delegate = self
    }

    // MARK: - Discovery

    /// Starts auto-discovery and attempts automatic reconnection if the TV was previously paired.
    func startAutoDiscovery() {
        if let savedName = currentTVName, let savedHost = currentHost {
            let isPaired = UserDefaults.standard.bool(forKey: AppConstants.StorageKeys.isPairedKey(for: savedHost))
            if isPaired {
                // Known paired TV: set connecting and attempt silent TLS reconnection
                currentStatus = .connecting(savedName)
                remoteService.connect(host: savedHost)
            } else {
                // Known TV but never paired: show as discovered, wait for user action
                currentStatus = .discovered(savedName)
            }
        } else {
            currentStatus = .searching
        }
        GoogleTVDiscovery.shared.startDiscovery()
    }

    // MARK: - GoogleTVDiscoveryDelegate

    func discoveryDidUpdateDevices(_ discovery: GoogleTVDiscovery, devices: [DiscoveredTV]) {
        guard let first = devices.first else { return }

        // Only update metadata when not already in an active session
        switch currentStatus {
        case .searching, .disconnected:
            currentTVName = first.name
            currentHost   = first.host

            let isPaired = UserDefaults.standard.bool(forKey: AppConstants.StorageKeys.isPairedKey(for: first.host))
            if isPaired {
                // Previously paired TV appeared on network: auto-reconnect silently
                currentStatus = .connecting(first.name)
                remoteService.connect(host: first.host)
            } else {
                // Newly discovered TV: surface it in UI without connecting
                currentStatus = .discovered(first.name)
            }

        case .discovered:
            // Refresh name/host in case mDNS resolved a better record
            currentTVName = first.name
            currentHost   = first.host
            currentStatus = .discovered(first.name)

        default:
            // Already connecting / connected / pairing — do not interrupt
            break
        }
    }

    // MARK: - Explicit Connection (user-initiated from DevicePickerSheet)

    /// Initiates a connection to the given TV. Called only via explicit user action.
    func connect(to tv: DiscoveredTV) {
        currentTVName = tv.name
        currentHost   = tv.host

        UserDefaults.standard.set(tv.name, forKey: AppConstants.StorageKeys.savedTvName)
        UserDefaults.standard.set(tv.host, forKey: AppConstants.StorageKeys.savedTvHost)

        let isPaired = UserDefaults.standard.bool(forKey: AppConstants.StorageKeys.isPairedKey(for: tv.host))
        currentStatus = .connecting(tv.name)

        if isPaired {
            remoteService.connect(host: tv.host)
        } else {
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
        print("[Client] PIN requested for \(name)")
    }

    func pairingDidSucceed() {
        guard let host = currentHost, let name = currentTVName else { return }
        print("[Client] Pairing succeeded with \(name)")
        UserDefaults.standard.set(true, forKey: AppConstants.StorageKeys.isPairedKey(for: host))
        HapticManager.playSuccess()
        pairingService.close()
        // Transition to control channel on port 6466
        currentStatus = .connecting(name)
        remoteService.connect(host: host)
    }

    func pairingDidFail(error: String) {
        print("[Client] Pairing failed: \(error)")
        // Return to discovered so user can retry from DevicePickerSheet
        if let name = currentTVName {
            currentStatus = .discovered(name)
        } else {
            currentStatus = .error("Pairing: \(error)")
        }
    }

    // MARK: - RemoteServiceDelegate

    func remoteServiceDidConnect() {
        guard let name = currentTVName else { return }
        currentStatus = .connected(name)
        print("[Client] Control channel active — \(name)")
    }

    func remoteServiceDidDisconnect(error: String?) {
        // On transient disconnection, go back to discovered so user can reconnect
        if let name = currentTVName {
            currentStatus = .discovered(name)
        } else {
            currentStatus = .disconnected
        }
    }

    // MARK: - Key Sending

    /// Sends a key event. ONLY operates when the status is .connected.
    /// Does NOT trigger pairing or any connection silently.
    func sendKey(_ key: AndroidKeyCode) {
        guard case .connected = currentStatus else {
            print("[Client] sendKey ignored — not connected. Current state: \(currentStatus)")
            return
        }
        remoteService.sendKey(key)
    }

    func disconnect() {
        remoteService.disconnect()
        pairingService.close()
        if let name = currentTVName {
            currentStatus = .discovered(name)
        } else {
            currentStatus = .disconnected
        }
    }
}
