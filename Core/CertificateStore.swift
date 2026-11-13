import Foundation
import Security

struct CertificateStore {

    // PKCS#12 codificado con 3DES / SHA1 (100% compatible con iOS 12 SecPKCS12Import)
    static let p12Base64 = "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"
    static let password = "remotetv"

    static func getClientIdentity() -> SecIdentity? {
        guard let data = Data(base64Encoded: p12Base64) else {
            print("[CertStore] Error decodificando Base64 de PKCS12")
            return nil
        }

        let options = NSDictionary(object: password, forKey: kSecImportExportPassphrase as NSString)

        var rawItems: CFArray?
        let status = SecPKCS12Import(data as CFData, options, &rawItems)

        guard status == errSecSuccess, let raw = rawItems else {
            print("[CertStore] Error en SecPKCS12Import: \(status)")
            return nil
        }

        let array = raw as NSArray
        guard array.count > 0, let firstDict = array[0] as? NSDictionary else {
            print("[CertStore] No se encontraron elementos en PKCS12")
            return nil
        }

        if let identity = firstDict[kSecImportItemIdentity as NSString] {
            return (identity as! SecIdentity)
        }

        return nil
    }
}
