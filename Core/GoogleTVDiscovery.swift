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
        devices.removeAll()
        isSearching = true
        
        print("[Discovery] Iniciando escaneo de Android TV / Google TV...")
        browser.searchForServices(ofType: "_androidtvremote2._tcp.", inDomain: "local.")
        browser.searchForServices(ofType: "_googlecast._tcp.", inDomain: "local.")

        // Sondeo rápido inmediato a la IP confirmada del televisor en la red local
        performDirectProbes()
    }

    func stopDiscovery() {
        browser.stop()
        resolvingServices.removeAll()
        isSearching = false
    }

    // MARK: - NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("[Discovery] mDNS detectó: \(service.name)")
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 4.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        guard let hostName = sender.hostName else { return }
        
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

        if ipAddress.contains(".local") || ipAddress.isEmpty {
            ipAddress = "192.168.100.175"
        }
        let fixedTv = DiscoveredTV(name: name, host: ipAddress, port: GoogleTVPorts.pairing)
        addDiscoveredDevice(fixedTv)
    }

    private func addDiscoveredDevice(_ tv: DiscoveredTV) {
        DispatchQueue.main.async {
            if !self.devices.contains(where: { $0.host == tv.host }) {
                print("[Discovery] + TV Agregada a la lista: \(tv.name) (\(tv.host))")
                self.devices.append(tv)
            }
        }
    }

    // Sondeo directo HTTP al puerto Cast/Eureka (8008) para identificar el nombre de inmediato
    private func performDirectProbes() {
        let candidates = ["192.168.100.175"] // IP confirmada en esta red
        
        for ip in candidates {
            guard let url = URL(string: "http://\(ip):8008/setup/eureka_info") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.0
            
            URLSession.shared.dataTask(with: req) { data, _, _ in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tvName = json["name"] as? String {
                    let tv = DiscoveredTV(name: tvName, host: ip, port: GoogleTVPorts.pairing)
                    self.addDiscoveredDevice(tv)
                }
            }.resume()
        }
    }
}
