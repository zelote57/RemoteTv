// PairingService.swift — Google TV Pairing Protocol (Polo v2)
// Protocolo mTLS sobre CFStream (iOS 12 compatible)
// Campos Protobuf verificados contra polo.proto oficial (tronikos/androidtvremote2)
// SHA-256 implementado en Swift puro (sin CommonCrypto)

import Foundation
import Security

// MARK: - Delegate

protocol PairingServiceDelegate: AnyObject {
    func pairingDidRequestPin()
    func pairingDidSucceed()
    func pairingDidFail(error: String)
}

// MARK: - RSA Parameters

private struct RSAParams {
    let modulus: Data
    let exponent: Data
}

// MARK: - PairingService

class PairingService: NSObject, StreamDelegate {

    weak var delegate: PairingServiceDelegate?

    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private var host: String = ""
    private var port: Int = Int(GoogleTVPorts.pairing)
    private var readBuffer = Data()
    private var pendingWriteData = Data()
    private var serverCertData: Data?
    private var timeoutTimer: Timer?

    private enum PairingState: String {
        case idle, connecting, sentRequest, sentOptions
        case sentConfiguration, waitingForSecret, sentSecret, paired, failed
    }
    private var state: PairingState = .idle

    // MARK: - API Pública

    func startPairing(host: String, port: Int = Int(GoogleTVPorts.pairing)) {
        switch state {
        case .idle, .failed: break
        default:
            print("[Pairing] Sesión ya activa (\(state.rawValue))")
            return
        }
        self.host = host
        self.port = port
        self.state = .connecting
        self.readBuffer = Data()
        self.pendingWriteData = Data()
        self.serverCertData = nil
        openTLSStreams()
    }

    func submitPin(_ pinCode: String) {
        guard case .waitingForSecret = state else {
            print("[Pairing] No esperando PIN ahora (state: \(state.rawValue))")
            return
        }
        let pin = pinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard pin.count == 6 else {
            notifyFail("El PIN debe tener exactamente 6 caracteres hex")
            return
        }
        // Verificar que es hex válido
        for ch in pin {
            if !"0123456789ABCDEF".contains(ch) {
                notifyFail("El PIN debe ser hexadecimal (0-9, A-F)")
                return
            }
        }
        guard let msg = buildSecretMessage(hexPin: pin) else {
            notifyFail("No se pudo calcular el secreto del PIN")
            return
        }
        send(data: msg)
        state = .sentSecret
        startTimeout(seconds: 10.0, context: "Esperando SecretAck")
        print("[Pairing] → Secret enviado con PIN \(pin)")
    }

    func close() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil
        state = .idle
        pendingWriteData = Data()
    }

    // MARK: - Timeout

    private func startTimeout(seconds: TimeInterval = 10.0, context: String) {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            guard self.state != .paired && self.state != .failed && self.state != .waitingForSecret else { return }
            print("[Pairing] ⏰ Timeout: \(context) (state: \(self.state.rawValue))")
            self.notifyFail("Timeout: \(context)")
        }
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
            notifyFail("No se pudo crear el socket hacia \(host):\(port)")
            return
        }

        let readStream = r.takeRetainedValue()
        let writeStream = w.takeRetainedValue()

        guard let identity = CertificateStore.getClientIdentity() else {
            let err = CertificateStore.lastError
            notifyFail("Error certificado cliente (OSStatus \(err))")
            return
        }

        let certArray: NSArray = [identity]
        let settings: NSDictionary = [
            kCFStreamSSLIsServer: kCFBooleanFalse as Any,
            kCFStreamSSLValidatesCertificateChain: kCFBooleanFalse as Any,
            kCFStreamSSLCertificates: certArray,
        ]

        CFReadStreamSetProperty(readStream, CFStreamPropertyKey(kCFStreamPropertySSLSettings), settings)
        CFWriteStreamSetProperty(writeStream, CFStreamPropertyKey(kCFStreamPropertySSLSettings), settings)

        let inStream  = readStream as InputStream
        let outStream = writeStream as OutputStream

        inStream.delegate  = self
        outStream.delegate = self
        inStream.schedule(in: .main, forMode: .common)
        outStream.schedule(in: .main, forMode: .common)
        inStream.open()
        outStream.open()

        inputStream  = inStream
        outputStream = outStream
        print("[Pairing] Streams TLS abriendo hacia \(host):\(port)")
        startTimeout(seconds: 10.0, context: "Conexión TLS")
    }

    // MARK: - StreamDelegate

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream === outputStream {
                print("[Pairing] ✅ TLS abierto — extrayendo cert servidor")
                extractServerCert()
                sendPairingRequest()
            }

        case .hasBytesAvailable:
            if aStream === inputStream {
                if serverCertData == nil { extractServerCert() }
                readAvailableBytes()
            }

        case .hasSpaceAvailable:
            // CRÍTICO: Este evento se dispara cuando el stream está listo para escribir.
            // Sin manejar esto, los datos en pendingWriteData se quedarían esperando.
            if aStream === outputStream {
                flushPendingData()
            }

        case .errorOccurred:
            let err = aStream.streamError as NSError?
            let msg = err?.localizedDescription ?? "Error desconocido"
            let code = err?.code ?? 0
            let fullMsg = "\(msg) (Code \(code))"
            print("[Pairing] ❌ Error stream: \(fullMsg)")
            guard state != .failed && state != .paired else { return }
            notifyFail(fullMsg)

        case .endEncountered:
            print("[Pairing] Stream cerrado por el servidor")
            guard state != .failed && state != .paired else { return }
            notifyFail("Conexión cerrada por el TV")

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

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Mensajes Polo v2 (campos verificados contra polo.proto)
    //
    // OuterMessage field numbers (de polo_pb2.py):
    //   1  = protocol_version (uint32, siempre 2)
    //   2  = status           (enum, 200 = STATUS_OK)
    //   10 = pairing_request
    //   11 = pairing_request_ack
    //   20 = options
    //   30 = configuration
    //   31 = configuration_ack
    //   40 = secret
    //   41 = secret_ack
    // ═══════════════════════════════════════════════════════════════════

    // Paso 1: Cliente → TV
    private func sendPairingRequest() {
        // PairingRequest: { service_name (f1), client_name (f2) }
        var inner = Data()
        inner.append(protoString(field: 1, value: "atvremote"))
        inner.append(protoString(field: 2, value: "Remote TV"))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))     // protocol_version = 2
        outer.append(protoVarint(field: 2, value: 200))   // STATUS_OK
        outer.append(protoBytes(field: 10, value: inner)) // pairing_request → field 10

        send(data: delimited(outer))
        state = .sentRequest
        startTimeout(seconds: 10.0, context: "PairingRequestAck")
        print("[Pairing] → PairingRequest (field 10)")
    }

    // Paso 2: Cliente → TV (tras recibir PairingRequestAck en field 11)
    private func sendOptions() {
        // Encoding: { type (f1)=3/HEXADECIMAL, symbol_length (f2)=6 }
        var encoding = Data()
        encoding.append(protoVarint(field: 1, value: 3)) // ENCODING_TYPE_HEXADECIMAL
        encoding.append(protoVarint(field: 2, value: 6)) // symbol_length = 6

        // Options: { input_encodings (f1, repeated), preferred_role (f3)=1/INPUT }
        var inner = Data()
        inner.append(protoBytes(field: 1, value: encoding)) // input_encodings
        inner.append(protoVarint(field: 3, value: 1))       // preferred_role = ROLE_TYPE_INPUT

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 20, value: inner))  // options → field 20

        send(data: delimited(outer))
        state = .sentOptions
        startTimeout(seconds: 10.0, context: "Options del TV")
        print("[Pairing] → Options (field 20) [input_encodings=HEX/6, role=INPUT]")
    }

    // Paso 3: Cliente → TV (tras recibir Options del TV en field 20)
    private func sendConfiguration() {
        // Encoding sub-message
        var encoding = Data()
        encoding.append(protoVarint(field: 1, value: 3)) // ENCODING_TYPE_HEXADECIMAL
        encoding.append(protoVarint(field: 2, value: 6)) // symbol_length = 6

        // Configuration: { encoding (f1), client_role (f2)=1/INPUT }
        var inner = Data()
        inner.append(protoBytes(field: 1, value: encoding)) // encoding
        inner.append(protoVarint(field: 2, value: 1))       // client_role = ROLE_TYPE_INPUT

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 30, value: inner))  // configuration → field 30

        send(data: delimited(outer))
        state = .sentConfiguration
        startTimeout(seconds: 10.0, context: "ConfigurationAck")
        print("[Pairing] → Configuration (field 30) — TV debería mostrar PIN ahora")
    }

    // MARK: - Secreto (PIN) — Algoritmo de tronikos/androidtvremote2

    private func buildSecretMessage(hexPin: String) -> Data? {
        // Extraer cert del servidor si no lo tenemos
        if serverCertData == nil { extractServerCert() }
        guard let serverCert = serverCertData else {
            print("[Pairing] Error: No hay cert del servidor para calcular secreto")
            return nil
        }

        // Obtener modulus y exponente del cliente y servidor
        guard let clientParams = rsaParameters(fromIdentity: CertificateStore.getClientIdentity()),
              let serverParams = rsaParameters(fromCertDER: serverCert) else {
            print("[Pairing] Error: No se pudieron extraer parámetros RSA")
            return nil
        }

        print("[Pairing] Client modulus: \(clientParams.modulus.count) bytes, exp: \(clientParams.exponent.count) bytes")
        print("[Pairing] Server modulus: \(serverParams.modulus.count) bytes, exp: \(serverParams.exponent.count) bytes")

        // Referencia (pairing.py):
        //   h = hashlib.sha256()
        //   h.update(_int_to_bytes(client_modulus))
        //   h.update(_int_to_bytes(client_exponent))
        //   h.update(_int_to_bytes(server_modulus))
        //   h.update(_int_to_bytes(server_exponent))
        //   h.update(bytes.fromhex(pairing_code[2:]))  ← últimos 4 chars hex = 2 bytes
        //   hash_result = h.digest()
        //   assert hash_result[0] == int(pairing_code[0:2], 16)

        let pinNonceHex = String(hexPin.suffix(4))  // últimos 4 chars hex
        let pinCheckHex = String(hexPin.prefix(2))   // primeros 2 chars hex

        var hashInput = Data()
        hashInput.append(clientParams.modulus)
        hashInput.append(clientParams.exponent)
        hashInput.append(serverParams.modulus)
        hashInput.append(serverParams.exponent)
        hashInput.append(contentsOf: hexToBytes(pinNonceHex))

        let hash = sha256(hashInput)

        // Verificación: hash[0] debe coincidir con primer byte del PIN
        let expectedByte = UInt8(pinCheckHex, radix: 16) ?? 0
        if hash[0] != expectedByte {
            print("[Pairing] ⚠️ Hash check: hash[0]=0x\(String(format:"%02X", hash[0])) vs pin[0:2]=0x\(pinCheckHex) — NO coincide")
            // El TV rechazará el secreto, pero lo enviamos para que el usuario vea el error
        } else {
            print("[Pairing] ✅ Hash check OK: hash[0]=0x\(String(format:"%02X", hash[0]))")
        }

        // Secret: { secret (f1, bytes) = hash_result }
        var inner = Data()
        inner.append(protoBytes(field: 1, value: hash))

        // OuterMessage field 40 = secret
        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 40, value: inner))  // secret → field 40

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
        let fields = protoParseFields(data)
        let fieldKeys = fields.keys.sorted()
        print("[Pairing] ← Mensaje (\(data.count) bytes) campos: \(fieldKeys)")

        // Verificar status (field 2)
        if let statusData = fields[2] {
            var off = 0
            if let statusVal = varintDecode(statusData, offset: &off), statusVal != 200 {
                print("[Pairing] ← Status error: \(statusVal)")
                notifyFail("TV respondió con status \(statusVal)")
                return
            }
        }

        if fields[11] != nil {
            // PairingRequestAck (field 11) → enviar Options
            print("[Pairing] ← PairingRequestAck (field 11)")
            timeoutTimer?.invalidate()
            if state == .sentRequest {
                sendOptions()
            }
        } else if fields[20] != nil {
            // Options del TV (field 20) → enviar Configuration
            print("[Pairing] ← Options del TV (field 20)")
            timeoutTimer?.invalidate()
            if state == .sentOptions {
                sendConfiguration()
            }
        } else if fields[31] != nil {
            // ConfigurationAck (field 31) → TV muestra PIN en pantalla
            print("[Pairing] ← ConfigurationAck (field 31) — ¡TV mostrando PIN!")
            timeoutTimer?.invalidate()
            state = .waitingForSecret
            DispatchQueue.main.async { self.delegate?.pairingDidRequestPin() }
        } else if fields[41] != nil {
            // SecretAck (field 41) → ¡Emparejamiento exitoso!
            print("[Pairing] ← SecretAck (field 41) — ¡¡EMPAREJADO EXITOSAMENTE!!")
            timeoutTimer?.invalidate()
            state = .paired
            DispatchQueue.main.async { self.delegate?.pairingDidSucceed() }
        } else {
            print("[Pairing] ← Mensaje no reconocido (\(data.count) bytes, hex: \(data.prefix(32).map { String(format: "%02x", $0) }.joined()))")
            if serverCertData == nil { extractServerCert() }
        }
    }

    // MARK: - Envío con buffer (fix: ya no descarta datos cuando hasSpaceAvailable=false)

    private func send(data: Data) {
        pendingWriteData.append(data)
        flushPendingData()
    }

    private func flushPendingData() {
        guard let stream = outputStream, !pendingWriteData.isEmpty else { return }
        while !pendingWriteData.isEmpty && stream.hasSpaceAvailable {
            let bytes = [UInt8](pendingWriteData)
            let written = stream.write(bytes, maxLength: bytes.count)
            if written > 0 {
                pendingWriteData.removeSubrange(0..<written)
                print("[Pairing] 📤 Enviados \(written) bytes (\(pendingWriteData.count) pendientes)")
            } else {
                break
            }
        }
    }

    private func notifyFail(_ msg: String) {
        timeoutTimer?.invalidate()
        state = .failed
        print("[Pairing] ❌ FALLO: \(msg)")
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
            case 0: // varint
                var o2 = idx
                guard varintDecode(data, offset: &o2) != nil else { return fields }
                fields[fieldNum] = data.subdata(in: idx..<o2); idx = o2
            case 2: // length-delimited
                var o2 = idx
                guard let len = varintDecode(data, offset: &o2) else { return fields }
                let end = o2 + Int(len)
                guard end <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: o2..<end); idx = end
            case 1: // 64-bit fixed
                guard idx + 8 <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: idx..<(idx+8)); idx += 8
            case 5: // 32-bit fixed
                guard idx + 4 <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: idx..<(idx+4)); idx += 4
            default:
                return fields
            }
        }
        return fields
    }

    // MARK: - Crypto: RSA Parameters

    private func rsaParameters(fromIdentity identity: SecIdentity?) -> RSAParams? {
        guard let identity = identity else { return nil }
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        guard let c = cert else { return nil }
        return rsaParameters(fromCertDER: SecCertificateCopyData(c) as Data)
    }

    private func rsaParameters(fromCertDER der: Data) -> RSAParams? {
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
        return rsaParamsFromPKCS1(keyDER)
    }

    /// Extrae módulo y exponente de un DER PKCS#1: SEQUENCE { INTEGER modulus, INTEGER exponent }
    private func rsaParamsFromPKCS1(_ der: Data) -> RSAParams? {
        var i = 0
        guard der.count > 2, der[i] == 0x30 else { return nil }
        i += 1
        let (_, seqLenBytes) = derLength(der, i); i += seqLenBytes

        // Primer INTEGER: módulo
        guard i < der.count, der[i] == 0x02 else { return nil }
        i += 1
        let (modLen, modLenBytes) = derLength(der, i); i += modLenBytes
        guard i + modLen <= der.count else { return nil }
        var modulus = der.subdata(in: i..<(i + modLen))
        if modulus.first == 0x00 { modulus = modulus.dropFirst() }
        i += modLen

        // Segundo INTEGER: exponente
        guard i < der.count, der[i] == 0x02 else { return nil }
        i += 1
        let (expLen, expLenBytes) = derLength(der, i); i += expLenBytes
        guard i + expLen <= der.count else { return nil }
        var exponent = der.subdata(in: i..<(i + expLen))
        if exponent.first == 0x00 { exponent = exponent.dropFirst() }

        return RSAParams(modulus: Data(modulus), exponent: Data(exponent))
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

    // MARK: - Crypto: Hex

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
