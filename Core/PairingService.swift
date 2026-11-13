// PairingService.swift — Google TV Pairing Protocol (Polo v2)
// Protocolo mTLS sobre CFStream (iOS 12 compatible)
// SHA-256 implementado en Swift puro (sin CommonCrypto)

import Foundation
import Security

// MARK: - Delegate

protocol PairingServiceDelegate: AnyObject {
    func pairingDidRequestPin()
    func pairingDidSucceed()
    func pairingDidFail(error: String)
}

// MARK: - PairingService

class PairingService: NSObject, StreamDelegate {

    weak var delegate: PairingServiceDelegate?

    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private var host: String = ""
    private var port: Int = 6466
    private var readBuffer = Data()
    private var serverCertData: Data?

    private enum PairingState {
        case idle, connecting, sentRequest, waitingForOption
        case sentOption, waitingForConfig, waitingForSecret, paired, failed
    }
    private var state: PairingState = .idle

    // MARK: - API Pública

    func startPairing(host: String, port: Int = 6466) {
        switch state {
        case .idle, .failed: break
        default:
            print("[Pairing] Sesión ya activa")
            return
        }
        self.host = host
        self.port = port
        self.state = .connecting
        self.readBuffer = Data()
        self.serverCertData = nil
        openTLSStreams()
    }

    func submitPin(_ hexPin: String) {
        guard case .waitingForSecret = state else {
            print("[Pairing] No esperando PIN ahora")
            return
        }
        guard let msg = buildSecretMessage(hexPin: hexPin) else {
            notifyFail("No se pudo calcular el secreto del PIN")
            return
        }
        send(data: msg)
        state = .paired
    }

    func close() {
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil
        state = .idle
    }

    // MARK: - CFStream con mTLS

    private func openTLSStreams() {
        var readCF: Unmanaged<CFReadStream>?
        var writeCF: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            host as CFString,
            UInt32(port),
            &readCF,
            &writeCF
        )

        guard let r = readCF, let w = writeCF else {
            notifyFail("No se pudo crear el socket")
            return
        }

        // Toll-free bridge: CFReadStream ↔ InputStream via NSInputStream
        let inStream  = r.takeRetainedValue() as AnyObject as! InputStream
        let outStream = w.takeRetainedValue() as AnyObject as! OutputStream

        applyTLS(toInput: inStream, output: outStream)

        inStream.delegate  = self
        outStream.delegate = self
        inStream.schedule(in: .main, forMode: .common)
        outStream.schedule(in: .main, forMode: .common)
        inStream.open()
        outStream.open()

        inputStream  = inStream
        outputStream = outStream
        print("[Pairing] Streams abiertos hacia \(host):\(port)")
    }

    private func applyTLS(toInput inStream: InputStream, output outStream: OutputStream) {
        guard let identity = CertificateStore.getClientIdentity() else {
            print("[Pairing] Error: Sin certificado de cliente")
            notifyFail("No se pudo cargar el certificado de cliente")
            return
        }

        inStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue,
                             forKey: Stream.PropertyKey.socketSecurityLevelKey)
        outStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue,
                              forKey: Stream.PropertyKey.socketSecurityLevelKey)

        // NSDictionary evita problemas de tipo CFString vs NSString en Swift
        let certArray: NSArray = [identity]
        let settings: NSDictionary = [
            kCFStreamSSLIsServer: false,
            kCFStreamSSLValidatesCertificateChain: false,
            kCFStreamSSLCertificates: certArray,
        ]
        let sslKey = Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String)
        inStream.setProperty(settings, forKey: sslKey)
        outStream.setProperty(settings, forKey: sslKey)
    }

    // MARK: - StreamDelegate

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream === outputStream {
                print("[Pairing] TLS abierto — extrayendo cert servidor")
                extractServerCert()
                sendPairingRequest()
            }

        case .hasBytesAvailable:
            if aStream === inputStream {
                if serverCertData == nil { extractServerCert() }
                readAvailableBytes()
            }

        case .errorOccurred:
            let msg = aStream.streamError?.localizedDescription ?? "Error desconocido"
            print("[Pairing] Error stream: \(msg)")
            guard state != .failed && state != .paired else { return }
            state = .failed
            DispatchQueue.main.async { self.delegate?.pairingDidFail(error: msg) }

        case .endEncountered:
            print("[Pairing] Stream cerrado por el servidor")
            guard state != .failed && state != .paired else { return }
            state = .failed
            DispatchQueue.main.async { self.delegate?.pairingDidFail(error: "Conexión cerrada por el TV") }

        default:
            break
        }
    }

    // MARK: - Certificado del servidor

    private func extractServerCert() {
        let key = Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerTrust as String)
        guard let trustVal = inputStream?.property(forKey: key) else {
            print("[Pairing] Trust del servidor no disponible aún")
            return
        }
        let trust = trustVal as! SecTrust
        let cert: SecCertificate?
        if #available(iOS 15.0, *) {
            cert = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        } else {
            cert = SecTrustGetCertificateAtIndex(trust, 0)
        }
        guard let serverCert = cert else {
            print("[Pairing] No se pudo obtener certificado del trust")
            return
        }
        serverCertData = SecCertificateCopyData(serverCert) as Data
        print("[Pairing] Cert servidor capturado (\(serverCertData!.count) bytes)")
    }

    // MARK: - Mensajes Polo

    private func sendPairingRequest() {
        var inner = Data()
        inner.append(protoString(field: 1, value: "androidtvremote"))
        inner.append(protoString(field: 2, value: "Remote TV"))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))    // protocol_version
        outer.append(protoVarint(field: 2, value: 200))  // STATUS_OK
        outer.append(protoBytes(field: 7, value: inner)) // pairing_request

        send(data: delimited(outer))
        state = .sentRequest
        print("[Pairing] PairingRequest enviado")
    }

    private func sendPairingOption() {
        var encMsg = Data()
        encMsg.append(protoVarint(field: 1, value: 3)) // ENCODING_TYPE_HEXADECIMAL
        encMsg.append(protoVarint(field: 2, value: 6)) // 6 chars

        var inner = Data()
        inner.append(protoBytes(field: 2, value: encMsg)) // output_encodings

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 11, value: inner)) // pairing_option

        send(data: delimited(outer))
        state = .sentOption
        print("[Pairing] PairingOption enviado")
    }

    private func sendPairingConfiguration() {
        var encMsg = Data()
        encMsg.append(protoVarint(field: 1, value: 3))
        encMsg.append(protoVarint(field: 2, value: 6))

        var inner = Data()
        inner.append(protoBytes(field: 1, value: encMsg))
        inner.append(protoVarint(field: 2, value: 1)) // ROLE_INPUT

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 12, value: inner)) // pairing_configuration

        send(data: delimited(outer))
        state = .waitingForSecret
        print("[Pairing] Config enviada — esperando PIN")
        DispatchQueue.main.async { self.delegate?.pairingDidRequestPin() }
    }

    private func buildSecretMessage(hexPin: String) -> Data? {
        if serverCertData == nil { extractServerCert() }
        guard let serverCert = serverCertData else { return nil }

        guard let clientMod = rsaModulus(fromIdentity: CertificateStore.getClientIdentity()),
              let serverMod = rsaModulus(fromCertDER: serverCert) else { return nil }

        var hashInput = Data()
        hashInput.append(clientMod)
        hashInput.append(contentsOf: [0x01])
        hashInput.append(serverMod)
        hashInput.append(contentsOf: [0x01])
        hashInput.append(contentsOf: hexToBytes(hexPin))

        let secretHash = sha256(hashInput)

        var inner = Data()
        inner.append(protoBytes(field: 1, value: secretHash))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 13, value: inner)) // pairing_secret

        return delimited(outer)
    }

    // MARK: - Lectura

    private func readAvailableBytes() {
        let bufSize = 4096
        var buf = [UInt8](repeating: 0, count: bufSize)
        while let s = inputStream, s.hasBytesAvailable {
            let n = s.read(&buf, maxLength: bufSize)
            if n > 0 { readBuffer.append(contentsOf: buf[0..<n]) }
            else { break }
        }
        processBuffer()
    }

    private func processBuffer() {
        while !readBuffer.isEmpty {
            var off = 0
            guard let msgLen = varintDecode(readBuffer, offset: &off) else { break }
            let total = off + Int(msgLen)
            guard readBuffer.count >= total else { break }
            let msgData = readBuffer.subdata(in: off..<total)
            readBuffer.removeSubrange(0..<total)
            handleMessage(msgData)
        }
    }

    private func handleMessage(_ data: Data) {
        let f = protoParseFields(data)
        if f[7] != nil {
            print("[Pairing] ← PairingRequestAck")
            if state == .sentRequest { state = .waitingForOption; sendPairingOption() }
        } else if f[11] != nil {
            print("[Pairing] ← PairingOption")
            if state == .sentOption { sendPairingConfiguration() }
        } else if f[12] != nil {
            print("[Pairing] ← PairingConfigurationAck")
        } else if f[13] != nil {
            print("[Pairing] ← PairingSecretAck — ¡Emparejado!")
            state = .paired
            DispatchQueue.main.async { self.delegate?.pairingDidSucceed() }
        } else {
            if serverCertData == nil { extractServerCert() }
            print("[Pairing] ← Mensaje desconocido (\(data.count) bytes)")
        }
    }

    // MARK: - Envío

    private func send(data: Data) {
        guard let stream = outputStream, stream.hasSpaceAvailable else { return }
        let bytes = [UInt8](data)
        stream.write(bytes, maxLength: bytes.count)
    }

    private func notifyFail(_ msg: String) {
        state = .failed
        DispatchQueue.main.async { self.delegate?.pairingDidFail(error: msg) }
    }

    // MARK: - Protobuf Helpers

    private func protoVarint(field: Int, value: Int) -> Data {
        var d = Data()
        d.append(varintEncode(UInt64(bitPattern: Int64(field << 3 | 0))))
        d.append(varintEncode(UInt64(bitPattern: Int64(value))))
        return d
    }

    private func protoBytes(field: Int, value: Data) -> Data {
        var d = Data()
        d.append(varintEncode(UInt64(bitPattern: Int64(field << 3 | 2))))
        d.append(varintEncode(UInt64(value.count)))
        d.append(value)
        return d
    }

    private func protoString(field: Int, value: String) -> Data {
        protoBytes(field: field, value: Data(value.utf8))
    }

    private func delimited(_ msg: Data) -> Data {
        var d = varintEncode(UInt64(msg.count))
        d.append(msg)
        return d
    }

    private func varintEncode(_ value: UInt64) -> Data {
        var v = value
        var result = Data()
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            result.append(byte)
        } while v != 0
        return result
    }

    private func varintDecode(_ data: Data, offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]; offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    private func protoParseFields(_ data: Data) -> [Int: Data] {
        var fields = [Int: Data]()
        var idx = 0
        while idx < data.count {
            var off = idx
            guard let tag = varintDecode(data, offset: &off) else { break }
            let fieldNum = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            idx = off
            switch wireType {
            case 0:
                var o2 = idx
                guard varintDecode(data, offset: &o2) != nil else { break }
                fields[fieldNum] = data.subdata(in: idx..<o2); idx = o2
            case 2:
                var o2 = idx
                guard let len = varintDecode(data, offset: &o2) else { break }
                let end = o2 + Int(len)
                guard end <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: o2..<end); idx = end
            default:
                idx = data.count
            }
        }
        return fields
    }

    // MARK: - Crypto Helpers

    private func hexToBytes(_ hex: String) -> [UInt8] {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var bytes = [UInt8]()
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
            if let b = UInt8(s[i..<j], radix: 16) { bytes.append(b) }
            i = j
        }
        return bytes
    }

    private func rsaModulus(fromIdentity identity: SecIdentity?) -> Data? {
        guard let identity = identity else { return nil }
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        guard let c = cert else { return nil }
        return rsaModulus(fromCertDER: SecCertificateCopyData(c) as Data)
    }

    private func rsaModulus(fromCertDER der: Data) -> Data? {
        guard let cert = SecCertificateCreateWithData(nil, der as CFData) else { return nil }

        var publicKey: SecKey?
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        SecTrustCreateWithCertificates([cert] as AnyObject, policy, &trust)
        if let t = trust {
            if #available(iOS 14.0, *) {
                publicKey = SecTrustCopyKey(t)
            } else {
                publicKey = SecTrustCopyPublicKey(t)
            }
        }
        guard let key = publicKey else { return nil }

        var err: Unmanaged<CFError>?
        guard let keyDER = SecKeyCopyExternalRepresentation(key, &err) as Data? else { return nil }
        return modulusFromPKCS1(keyDER)
    }

    // Extrae el módulo RSA de un DER PKCS#1 (SEQUENCE { INTEGER, INTEGER })
    private func modulusFromPKCS1(_ der: Data) -> Data? {
        var i = 0
        guard der.count > 2, der[i] == 0x30 else { return nil }
        i += 1
        let (_, seqLen) = derLength(der, i); i += seqLen
        guard i < der.count, der[i] == 0x02 else { return nil }
        i += 1
        let (modLen, modLenBytes) = derLength(der, i); i += modLenBytes
        guard i + modLen <= der.count else { return nil }
        var mod = der.subdata(in: i..<(i + modLen))
        if mod.first == 0x00 { mod = mod.dropFirst() }
        return mod
    }

    private func derLength(_ data: Data, _ idx: Int) -> (Int, Int) {
        guard idx < data.count else { return (0, 1) }
        let b = data[idx]
        if b & 0x80 == 0 { return (Int(b), 1) }
        let n = Int(b & 0x7F)
        var len = 0
        for k in 1...n {
            guard idx + k < data.count else { break }
            len = len << 8 | Int(data[idx + k])
        }
        return (len, 1 + n)
    }

    // MARK: - SHA-256 puro en Swift (RFC 6234) — sin CommonCrypto

    private func sha256(_ data: Data) -> Data {
        let K: [UInt32] = [
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
        ]
        func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }

        var H: [UInt32] = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
                           0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
        var msg = [UInt8](data)
        let origBits = UInt64(msg.count) * 8
        msg.append(0x80)
        while (msg.count % 64) != 56 { msg.append(0x00) }
        for shift in stride(from: 56, through: 0, by: -8) {
            msg.append(UInt8((origBits >> shift) & 0xff))
        }

        for chunk in stride(from: 0, to: msg.count, by: 64) {
            var W = [UInt32](repeating: 0, count: 64)
            for t in 0..<16 {
                let j = chunk + t * 4
                W[t] = UInt32(msg[j])<<24 | UInt32(msg[j+1])<<16 | UInt32(msg[j+2])<<8 | UInt32(msg[j+3])
            }
            for t in 16..<64 {
                let s0 = rotr(W[t-15],7) ^ rotr(W[t-15],18) ^ (W[t-15] >> 3)
                let s1 = rotr(W[t-2],17) ^ rotr(W[t-2],19)  ^ (W[t-2] >> 10)
                W[t] = W[t-16] &+ s0 &+ W[t-7] &+ s1
            }
            var (a,b,c,d,e,f,g,h) = (H[0],H[1],H[2],H[3],H[4],H[5],H[6],H[7])
            for t in 0..<64 {
                let S1   = rotr(e,6) ^ rotr(e,11) ^ rotr(e,25)
                let ch   = (e & f) ^ (~e & g)
                let T1   = h &+ S1 &+ ch &+ K[t] &+ W[t]
                let S0   = rotr(a,2) ^ rotr(a,13) ^ rotr(a,22)
                let maj  = (a & b) ^ (a & c) ^ (b & c)
                let T2   = S0 &+ maj
                h=g; g=f; f=e; e=d &+ T1; d=c; c=b; b=a; a=T1 &+ T2
            }
            H[0]=H[0]&+a; H[1]=H[1]&+b; H[2]=H[2]&+c; H[3]=H[3]&+d
            H[4]=H[4]&+e; H[5]=H[5]&+f; H[6]=H[6]&+g; H[7]=H[7]&+h
        }
        var digest = Data()
        H.forEach { w in
            digest.append(UInt8((w>>24)&0xff)); digest.append(UInt8((w>>16)&0xff))
            digest.append(UInt8((w>>8)&0xff));  digest.append(UInt8(w&0xff))
        }
        return digest
    }
}
