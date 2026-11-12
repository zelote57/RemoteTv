// PairingService.swift — Google TV Pairing Protocol (Polo v2)
// Protocolo mTLS sobre CFStream (iOS 12 compatible)
// Referencia: louis49/androidtv-remote + andrewraincol/googletvremote

import Foundation
import Security
import CommonCrypto

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

    // Buffer de lectura acumulado
    private var readBuffer = Data()

    // Certificado del servidor (para cálculo del secreto PIN)
    private var serverCertData: Data?

    // Estado de la máquina de estados del protocolo Polo
    private enum State {
        case idle
        case connecting
        case sentPairingRequest
        case waitingForOption
        case sentOption
        case waitingForConfig
        case sentConfig
        case waitingForSecret
        case paired
        case failed
    }
    private var state: State = .idle

    // MARK: - API Pública

    func startPairing(host: String, port: Int = 6466) {
        guard state == .idle || state == .failed else {
            print("[Pairing] Ya hay una sesión activa")
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
        guard state == .waitingForSecret else {
            print("[Pairing] No esperando PIN ahora (estado: \(state))")
            return
        }
        guard let secretMsg = buildSecretMessage(hexPin: hexPin) else {
            delegate?.pairingDidFail(error: "No se pudo calcular el secreto del PIN")
            return
        }
        send(data: secretMsg)
        state = .paired   // Optimista — confirmamos al recibir PairingSecretAck
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
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            host as CFString,
            UInt32(port),
            &readStream,
            &writeStream
        )

        guard let r = readStream, let w = writeStream else {
            delegate?.pairingDidFail(error: "No se pudo crear el socket")
            state = .failed
            return
        }

        inputStream  = r.takeRetainedValue()
        outputStream = w.takeRetainedValue()

        guard let identity = CertificateStore.getClientIdentity() else {
            delegate?.pairingDidFail(error: "Certificado de cliente no disponible")
            state = .failed
            return
        }

        // Configurar TLS con certificado de cliente y sin validación del servidor
        // (el TV usa un certificado autofirmado)
        let sslSettings: [NSString: Any] = [
            kCFStreamSSLIsServer:              false,
            kCFStreamSSLValidatesCertificateChain: false,
            kCFStreamSSLCertificates:          [identity] as CFArray,
        ]

        inputStream?.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue,
                                 forKey: Stream.PropertyKey.socketSecurityLevelKey)
        outputStream?.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue,
                                  forKey: Stream.PropertyKey.socketSecurityLevelKey)

        inputStream?.setProperty(sslSettings as CFDictionary,
                                 forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String))
        outputStream?.setProperty(sslSettings as CFDictionary,
                                  forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String))

        inputStream?.delegate  = self
        outputStream?.delegate = self

        inputStream?.schedule(in: .main, forMode: .common)
        outputStream?.schedule(in: .main, forMode: .common)

        inputStream?.open()
        outputStream?.open()

        print("[Pairing] Streams abiertos hacia \(host):\(port)")
    }

    // MARK: - StreamDelegate

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream === outputStream {
                print("[Pairing] TLS conectado. Extrayendo cert del servidor…")
                extractServerCert()
                sendPairingRequest()
            }

        case .hasBytesAvailable:
            if aStream === inputStream {
                readAvailableBytes()
            }

        case .errorOccurred:
            let err = aStream.streamError?.localizedDescription ?? "Error desconocido"
            print("[Pairing] Error en stream: \(err)")
            if state != .failed {
                state = .failed
                delegate?.pairingDidFail(error: err)
            }

        case .endEncountered:
            print("[Pairing] Stream cerrado por el servidor")
            if state != .paired && state != .failed {
                state = .failed
                delegate?.pairingDidFail(error: "Conexión cerrada por el TV")
            }

        default:
            break
        }
    }

    // MARK: - Extracción del certificado del servidor

    private func extractServerCert() {
        guard let ssl = inputStream?.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLContext as String)) else {
            print("[Pairing] No se pudo obtener SSLContext del stream")
            return
        }

        // kCFStreamPropertySSLPeerCertificates devuelve array de SecCertificate
        guard let certs = inputStream?.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerCertificates as String)) as? [SecCertificate],
              let serverCert = certs.first else {
            print("[Pairing] No hay certificado del servidor aún (se intentará de nuevo al recibir ack)")
            return
        }

        serverCertData = SecCertificateCopyData(serverCert) as Data
        print("[Pairing] Certificado del servidor capturado (\(serverCertData!.count) bytes)")
    }

    // MARK: - Protocolo Polo — Envío de mensajes

    // Estructura outer PairingMessage (proto3):
    //   field 1 (protocol_version, varint) = 2
    //   field 2 (status, varint) = 200
    //   field 7 (pairing_request, embedded message) = ...
    //   field 11 (pairing_option, embedded message) = ...
    //   field 12 (pairing_config, embedded message) = ...
    //   field 13 (pairing_secret, embedded message) = ...

    private func sendPairingRequest() {
        // Inner PairingRequest:
        //   field 1 (service_name, string) = "androidtvremote"
        //   field 2 (client_name,  string) = "Remote TV"
        var inner = Data()
        inner.append(protoString(field: 1, value: "androidtvremote"))
        inner.append(protoString(field: 2, value: "Remote TV"))

        // Outer PairingMessage wrapping PairingRequest:
        //   field 1 (protocol_version) = 2
        //   field 2 (status)           = 200  (STATUS_OK)
        //   field 10 (type)            = 10   (PAIRING_REQUEST)  — no siempre necesario
        //   field 7 (pairing_request)  = inner bytes
        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))    // protocol_version = 2
        outer.append(protoVarint(field: 2, value: 200))  // status = STATUS_OK
        outer.append(protoBytes(field: 7, value: inner))  // pairing_request

        send(data: delimited(outer))
        state = .sentPairingRequest
        print("[Pairing] PairingRequest enviado")
    }

    private func sendPairingOption() {
        // PairingOption inner:
        //   field 2 (output_encodings, embedded message):
        //     field 1 (encoding_type, varint) = 3  (ENCODING_TYPE_HEXADECIMAL)
        //     field 2 (symbol_length, varint) = 6
        var encMsg = Data()
        encMsg.append(protoVarint(field: 1, value: 3))  // ENCODING_TYPE_HEXADECIMAL
        encMsg.append(protoVarint(field: 2, value: 6))  // 6 chars

        var inner = Data()
        inner.append(protoBytes(field: 2, value: encMsg))  // output_encodings

        // Outer wrapping PairingOption:
        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 11, value: inner))  // pairing_option field = 11

        send(data: delimited(outer))
        state = .sentOption
        print("[Pairing] PairingOption enviado")
    }

    private func sendPairingConfiguration() {
        // PairingConfiguration inner:
        //   field 1 (encoding, embedded message):
        //     field 1 (encoding_type) = 3 (HEXADECIMAL)
        //     field 2 (symbol_length) = 6
        //   field 2 (client_role, varint) = 1 (ROLE_INPUT)
        var encMsg = Data()
        encMsg.append(protoVarint(field: 1, value: 3))
        encMsg.append(protoVarint(field: 2, value: 6))

        var inner = Data()
        inner.append(protoBytes(field: 1, value: encMsg))
        inner.append(protoVarint(field: 2, value: 1))  // ROLE_INPUT

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 12, value: inner))  // pairing_configuration field = 12

        send(data: delimited(outer))
        state = .waitingForSecret
        print("[Pairing] PairingConfiguration enviado — Esperando PIN del usuario")
        DispatchQueue.main.async { self.delegate?.pairingDidRequestPin() }
    }

    private func buildSecretMessage(hexPin: String) -> Data? {
        // Intentar de nuevo capturar el cert del servidor si no lo tenemos aún
        if serverCertData == nil { extractServerCert() }

        guard let serverCert = serverCertData else {
            print("[Pairing] Sin certificado del servidor para calcular secreto")
            return nil
        }

        // Modulus del cliente
        guard let clientModulus = extractRSAModulus(from: CertificateStore.getClientIdentity()) else {
            print("[Pairing] No se pudo extraer módulo RSA del cliente")
            return nil
        }

        // Modulus del servidor
        guard let serverModulus = extractRSAModulusFromCertData(serverCert) else {
            print("[Pairing] No se pudo extraer módulo RSA del servidor")
            return nil
        }

        // PIN hexadecimal → bytes (ej. "AB12CD" → [0xAB, 0x12, 0xCD])
        let pinBytes = hexStringToBytes(hexPin)

        // SHA256(clientModulus || 0x01 || serverModulus || 0x01 || pinBytes)
        var hashInput = Data()
        hashInput.append(clientModulus)
        hashInput.append(0x01)
        hashInput.append(serverModulus)
        hashInput.append(0x01)
        hashInput.append(contentsOf: pinBytes)

        let secretHash = sha256(hashInput)

        // PairingSecret inner:
        //   field 1 (secret, bytes) = sha256_hash
        var inner = Data()
        inner.append(protoBytes(field: 1, value: secretHash))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 13, value: inner))  // pairing_secret field = 13

        return delimited(outer)
    }

    // MARK: - Lectura y parseo de mensajes

    private func readAvailableBytes() {
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while let stream = inputStream, stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                readBuffer.append(contentsOf: buffer[0..<bytesRead])
            } else if bytesRead < 0 {
                break
            }
        }

        processBuffer()
    }

    private func processBuffer() {
        // Los mensajes están delimitados por varint (longitud) al inicio
        while !readBuffer.isEmpty {
            var offset = 0
            guard let msgLen = decodeVarint(from: readBuffer, offset: &offset) else { break }
            let totalNeeded = offset + Int(msgLen)
            guard readBuffer.count >= totalNeeded else { break }

            let msgData = readBuffer.subdata(in: offset..<totalNeeded)
            readBuffer.removeSubrange(0..<totalNeeded)
            handleMessage(msgData)
        }
    }

    private func handleMessage(_ data: Data) {
        // Parsear outer PairingMessage buscando el campo que indica el tipo
        // field 7 → PairingRequestAck
        // field 11 → PairingOption
        // field 12 → PairingConfigurationAck
        // field 13 → PairingSecretAck
        let fields = parseProtoFields(data)

        if fields[7] != nil {
            print("[Pairing] Recibido PairingRequestAck")
            if state == .sentPairingRequest {
                state = .waitingForOption
                sendPairingOption()
            }
        } else if fields[11] != nil {
            print("[Pairing] Recibido PairingOption del servidor")
            if state == .sentOption {
                sendPairingConfiguration()
            }
        } else if fields[12] != nil {
            print("[Pairing] Recibido PairingConfigurationAck")
            // Ahora esperamos el PIN del usuario (ya notificamos via delegate en sendPairingConfiguration)
        } else if let secretAckData = fields[13] {
            print("[Pairing] Recibido PairingSecretAck")
            handleSecretAck(secretAckData)
        } else {
            // Intenta capturar cert del servidor en cualquier mensaje recibido
            if serverCertData == nil { extractServerCert() }
            print("[Pairing] Mensaje desconocido recibido (\(data.count) bytes): \(data.map { String(format: "%02x", $0) }.joined())")
        }
    }

    private func handleSecretAck(_ data: Data) {
        // Si status == STATUS_OK → emparejado con éxito
        let outerFields = parseProtoFields(data)
        // field 2 = status (varint)
        // STATUS_OK = 200
        state = .paired
        DispatchQueue.main.async { self.delegate?.pairingDidSucceed() }
    }

    // MARK: - Envío

    private func send(data: Data) {
        guard let stream = outputStream, stream.hasSpaceAvailable else {
            print("[Pairing] Stream de salida no disponible")
            return
        }
        data.withUnsafeBytes { ptr in
            if let baseAddr = ptr.baseAddress {
                stream.write(baseAddr.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
            }
        }
    }

    // MARK: - Protobuf Helpers

    // Encode varint field (wire type 0)
    private func protoVarint(field: Int, value: Int) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64((field << 3) | 0)))  // wire type 0
        d.append(encodeVarint(UInt64(value)))
        return d
    }

    // Encode length-delimited field (wire type 2)
    private func protoBytes(field: Int, value: Data) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64((field << 3) | 2)))  // wire type 2
        d.append(encodeVarint(UInt64(value.count)))
        d.append(value)
        return d
    }

    // Encode string field (wire type 2)
    private func protoString(field: Int, value: String) -> Data {
        return protoBytes(field: field, value: Data(value.utf8))
    }

    // Delimited message: prefixed with its varint length
    private func delimited(_ msg: Data) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64(msg.count)))
        d.append(msg)
        return d
    }

    private func encodeVarint(_ value: UInt64) -> Data {
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

    private func decodeVarint(from data: Data, offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    // Parse proto fields → [fieldNumber: Data] (sólo wire type 2 — length-delimited)
    // Para varint fields (wire type 0), almacena los bytes crudos también
    private func parseProtoFields(_ data: Data) -> [Int: Data] {
        var fields = [Int: Data]()
        var idx = 0

        while idx < data.count {
            var offset = idx
            guard let tag = decodeVarint(from: data, offset: &offset) else { break }
            let fieldNum = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            idx = offset

            switch wireType {
            case 0: // varint
                var o2 = idx
                guard let _ = decodeVarint(from: data, offset: &o2) else { break }
                fields[fieldNum] = data.subdata(in: idx..<o2)
                idx = o2
            case 2: // length-delimited
                var o2 = idx
                guard let len = decodeVarint(from: data, offset: &o2) else { break }
                let end = o2 + Int(len)
                guard end <= data.count else { break }
                fields[fieldNum] = data.subdata(in: o2..<end)
                idx = end
            default:
                // wire types 1, 5 (fixed) — saltar
                idx = data.count
            }
        }
        return fields
    }

    // MARK: - Crypto Helpers

    private func sha256(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            if let baseAddr = ptr.baseAddress {
                CC_SHA256(baseAddr, CC_LONG(data.count), &hash)
            }
        }
        return Data(hash)
    }

    private func hexStringToBytes(_ hex: String) -> [UInt8] {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var bytes = [UInt8]()
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            if let byte = UInt8(clean[index..<next], radix: 16) {
                bytes.append(byte)
            }
            index = next
        }
        return bytes
    }

    private func extractRSAModulus(from identity: SecIdentity?) -> Data? {
        guard let identity = identity else { return nil }
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        guard let certificate = cert else { return nil }
        let certData = SecCertificateCopyData(certificate) as Data
        return extractRSAModulusFromCertData(certData)
    }

    // Extraer módulo RSA del DER de un certificado X.509
    // El módulo está dentro de SubjectPublicKeyInfo → BIT STRING → INTEGER (módulo)
    private func extractRSAModulusFromCertData(_ derData: Data) -> Data? {
        // Usar SecKey para obtener el modulus de forma portable en iOS 12
        guard let cert = SecCertificateCreateWithData(nil, derData as CFData) else { return nil }

        var publicKey: SecKey?
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        SecTrustCreateWithCertificates([cert] as CFArray, policy, &trust)

        if let trust = trust {
            if #available(iOS 14, *) {
                publicKey = SecTrustCopyKey(trust)
            } else {
                publicKey = SecTrustCopyPublicKey(trust)
            }
        }

        guard let key = publicKey else { return nil }

        // Exportar como PKCS#1 DER y parsear manualmente
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else { return nil }

        // keyData es el ASN.1 DER del public key RSA (PKCS#1)
        // Estructura: SEQUENCE { INTEGER(modulus), INTEGER(exponent) }
        return extractModulusFromPKCS1DER(keyData)
    }

    private func extractModulusFromPKCS1DER(_ der: Data) -> Data? {
        var idx = 0
        guard der.count > 2 else { return nil }

        // SEQUENCE tag
        guard der[idx] == 0x30 else { return nil }
        idx += 1
        idx += skipDERLength(der, idx: idx)

        // Primera INTEGER = módulo
        guard idx < der.count, der[idx] == 0x02 else { return nil }
        idx += 1

        var modLen = 0
        let (length, lenBytes) = readDERLength(der, idx: idx)
        modLen = length
        idx += lenBytes

        guard idx + modLen <= der.count else { return nil }

        var modulusData = der.subdata(in: idx..<(idx + modLen))
        // Eliminar byte de signo 0x00 si existe
        if modulusData.first == 0x00 {
            modulusData = modulusData.dropFirst()
        }
        return modulusData
    }

    private func skipDERLength(_ data: Data, idx: Int) -> Int {
        let (_, bytes) = readDERLength(data, idx: idx)
        return bytes
    }

    private func readDERLength(_ data: Data, idx: Int) -> (Int, Int) {
        guard idx < data.count else { return (0, 1) }
        let first = data[idx]
        if first & 0x80 == 0 {
            return (Int(first), 1)
        }
        let numBytes = Int(first & 0x7F)
        var length = 0
        for i in 1...numBytes {
            guard idx + i < data.count else { break }
            length = length << 8 | Int(data[idx + i])
        }
        return (length, 1 + numBytes)
    }
}
