import Foundation

struct DiscoveredTV: Equatable {
    let name: String
    let host: String
    let port: UInt16
}

protocol GoogleTVDiscoveryDelegate: AnyObject {
    func discoveryDidUpdateDevices(_ discovery: GoogleTVDiscovery, devices: [DiscoveredTV])
}

class GoogleTVDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

    static let shared = GoogleTVDiscovery()

    weak var delegate: GoogleTVDiscoveryDelegate?

    private(set) var devices: [DiscoveredTV] = [] {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.discoveryDidUpdateDevices(self, devices: self.devices)
            }
        }
    }

    private let browser = NetServiceBrowser()
    private var resolvingServices: [NetService] = []
    private var isSearching = false

    override init() {
        super.init()
        browser.delegate = self
    }

    func startDiscovery() {
        guard !isSearching else { return }
        isSearching = true
        devices.removeAll()
        
        print("[Discovery] Iniciando búsqueda mDNS de Google TV / Android TV...")
        browser.searchForServices(ofType: "_androidtvremote2._tcp.", inDomain: "local.")

        // Escaneo rápido de respaldo en la red local (para detectar dispositivos al instante)
        performFastSubnetScan()
    }

    func stopDiscovery() {
        browser.stop()
        resolvingServices.removeAll()
        isSearching = false
    }

    // MARK: - NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("[Discovery] Servicio mDNS encontrado: \(service.name)")
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        guard let hostName = sender.hostName else { return }
        
        // Obtener la dirección IP de los datos del socket
        var ipAddress = hostName
        if let addresses = sender.addresses {
            for addressData in addresses {
                var storage = sockaddr_storage()
                (addressData as NSData).getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
                if storage.ss_family == sa_family_t(AF_INET) {
                    var addr = sockaddr_in()
                    (addressData as NSData).getBytes(&addr, length: MemoryLayout<sockaddr_in>.size)
                    let ipStr = String(cString: inet_ntoa(addr.sin_addr))
                    ipAddress = ipStr
                    break
                }
            }
        }

        let tv = DiscoveredTV(name: name, host: ipAddress, port: UInt16(sender.port > 0 ? sender.port : 6466))
        addDiscoveredDevice(tv)
    }

    private func addDiscoveredDevice(_ tv: DiscoveredTV) {
        DispatchQueue.main.async {
            if !self.devices.contains(where: { $0.host == tv.host }) {
                print("[Discovery] + Dispositivo agregado: \(tv.name) (\(tv.host))")
                self.devices.append(tv)
            }
        }
    }

    // Escaneo rápido asistido por protocolo Cast / Eureka (puerto 8008)
    private func performFastSubnetScan() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Verificamos si hay una IP guardada primero
            if let savedHost = UserDefaults.standard.string(forKey: "saved_tv_ip") {
                self.probeHost(savedHost)
            }
            
            // Sondeo directo a la IP confirmada de la red local
            self.probeHost("192.168.100.175")
        }
    }

    private func probeHost(_ ip: String) {
        guard let url = URL(string: "http://\(ip):8008/setup/eureka_info") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                let tv = DiscoveredTV(name: name, host: ip, port: 6466)
                self.addDiscoveredDevice(tv)
            }
        }
        task.resume()
    }
}
