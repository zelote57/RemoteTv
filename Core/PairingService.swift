// PairingService.swift — Google TV Pairing Protocol (Polo v2)
// Protocolo mTLS sobre CFStream (iOS 12 compatible)
// Referencia: louis49/androidtv-remote + andrewraincol/googletvremote

import Foundation
import Security

// MARK: - SHA256 sin CommonCrypto (usando Security.framework)
// Usamos CryptoKit-free SHA256 via CC functions through a bridging approach.
// En su lugar implementamos SHA256 en pure Swift para evitar problemas de módulo.

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
    private enum PairingState: Equatable {
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
    private var state: PairingState = .idle

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
        // Usamos NSString keys para evitar problemas de cast con CFString
        let sslSettings: [String: Any] = [
            kCFStreamSSLIsServer as String:                   false,
            kCFStreamSSLValidatesCertificateChain as String:  false,
            kCFStreamSSLCertificates as String:               [identity] as CFArray,
        ]

        inputStream?.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue,
                                 forKey: Stream.PropertyKey.socketSecurityLevelKey)
        outputStream?.setProperty(StreamSocketSecurityLevel.negotiatedSSL.rawValue,
                                  forKey: Stream.PropertyKey.socketSecurityLevelKey)

        let sslKey = Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String)
        inputStream?.setProperty(sslSettings as CFDictionary, forKey: sslKey)
        outputStream?.setProperty(sslSettings as CFDictionary, forKey: sslKey)

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
                DispatchQueue.main.async { self.delegate?.pairingDidFail(error: err) }
            }

        case .endEncountered:
            print("[Pairing] Stream cerrado por el servidor")
            if state != .paired && state != .failed {
                state = .failed
                DispatchQueue.main.async {
                    self.delegate?.pairingDidFail(error: "Conexión cerrada por el TV")
                }
            }

        default:
            break
        }
    }

    // MARK: - Extracción del certificado del servidor

    private func extractServerCert() {
        let certKey = Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerCertificates as String)
        guard let certs = inputStream?.property(forKey: certKey) as? [SecCertificate],
              let serverCert = certs.first else {
            print("[Pairing] No hay certificado del servidor aún (se intentará de nuevo al recibir ack)")
            return
        }

        serverCertData = SecCertificateCopyData(serverCert) as Data
        print("[Pairing] Certificado del servidor capturado (\(serverCertData!.count) bytes)")
    }

    // MARK: - Protocolo Polo — Envío de mensajes

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
        //   field 7 (pairing_request)  = inner bytes
        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 7, value: inner))

        send(data: delimited(outer))
        state = .sentPairingRequest
        print("[Pairing] PairingRequest enviado")
    }

    private func sendPairingOption() {
        // PairingOption inner:
        //   field 2 (output_encodings):
        //     field 1 (encoding_type) = 3 (HEXADECIMAL)
        //     field 2 (symbol_length) = 6
        var encMsg = Data()
        encMsg.append(protoVarint(field: 1, value: 3))
        encMsg.append(protoVarint(field: 2, value: 6))

        var inner = Data()
        inner.append(protoBytes(field: 2, value: encMsg))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 11, value: inner))

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
        inner.append(protoVarint(field: 2, value: 1))  // ROLE_INPUT

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 12, value: inner))

        send(data: delimited(outer))
        state = .waitingForSecret
        print("[Pairing] PairingConfiguration enviado — Esperando PIN del usuario")
        DispatchQueue.main.async { self.delegate?.pairingDidRequestPin() }
    }

    private func buildSecretMessage(hexPin: String) -> Data? {
        if serverCertData == nil { extractServerCert() }

        guard let serverCert = serverCertData else {
            print("[Pairing] Sin certificado del servidor para calcular secreto")
            return nil
        }

        guard let clientModulus = extractRSAModulus(fromIdentity: CertificateStore.getClientIdentity()) else {
            print("[Pairing] No se pudo extraer módulo RSA del cliente")
            return nil
        }

        guard let serverModulus = extractRSAModulusFromCertData(serverCert) else {
            print("[Pairing] No se pudo extraer módulo RSA del servidor")
            return nil
        }

        let pinBytes = hexStringToBytes(hexPin)

        // SHA256(clientModulus || 0x01 || serverModulus || 0x01 || pinBytes)
        var hashInput = Data()
        hashInput.append(clientModulus)
        hashInput.append(contentsOf: [0x01])
        hashInput.append(serverModulus)
        hashInput.append(contentsOf: [0x01])
        hashInput.append(contentsOf: pinBytes)

        let secretHash = sha256Swift(hashInput)

        var inner = Data()
        inner.append(protoBytes(field: 1, value: secretHash))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: 2))
        outer.append(protoVarint(field: 2, value: 200))
        outer.append(protoBytes(field: 13, value: inner))

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
        } else if let _ = fields[13] {
            print("[Pairing] Recibido PairingSecretAck")
            state = .paired
            DispatchQueue.main.async { self.delegate?.pairingDidSucceed() }
        } else {
            if serverCertData == nil { extractServerCert() }
            print("[Pairing] Mensaje desconocido recibido (\(data.count) bytes)")
        }
    }

    // MARK: - Envío

    private func send(data: Data) {
        guard let stream = outputStream, stream.hasSpaceAvailable else {
            print("[Pairing] Stream de salida no disponible")
            return
        }
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            if let baseAddr = ptr.baseAddress {
                stream.write(baseAddr.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
            }
        }
    }

    // MARK: - Protobuf Helpers

    private func protoVarint(field: Int, value: Int) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64((field << 3) | 0)))
        d.append(encodeVarint(UInt64(bitPattern: Int64(value))))
        return d
    }

    private func protoBytes(field: Int, value: Data) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64((field << 3) | 2)))
        d.append(encodeVarint(UInt64(value.count)))
        d.append(value)
        return d
    }

    private func protoString(field: Int, value: String) -> Data {
        return protoBytes(field: field, value: Data(value.utf8))
    }

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
                guard decodeVarint(from: data, offset: &o2) != nil else { break }
                fields[fieldNum] = data.subdata(in: idx..<o2)
                idx = o2
            case 2: // length-delimited
                var o2 = idx
                guard let len = decodeVarint(from: data, offset: &o2) else { break }
                let end = o2 + Int(len)
                guard end <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: o2..<end)
                idx = end
            default:
                idx = data.count
            }
        }
        return fields
    }

    // MARK: - SHA256 (Pure Swift — sin CommonCrypto)

    private func sha256Swift(_ data: Data) -> Data {
        let bytes = Array(data)
        return Data(sha256Digest(bytes))
    }

    // SHA-256 puro en Swift — RFC 6234
    private func sha256Digest(_ message: [UInt8]) -> [UInt8] {
        var k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
            0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
            0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
            0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
            0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
            0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
            0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
            0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
            0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]

        var h0: UInt32 = 0x6a09e667
        var h1: UInt32 = 0xbb67ae85
        var h2: UInt32 = 0x3c6ef372
        var h3: UInt32 = 0xa54ff53a
        var h4: UInt32 = 0x510e527f
        var h5: UInt32 = 0x9b05688c
        var h6: UInt32 = 0x1f83d9ab
        var h7: UInt32 = 0x5be0cd19

        // Pre-processing: padding
        var msg = message
        let origLenBits = UInt64(message.count) * 8
        msg.append(0x80)
        while (msg.count % 64) != 56 {
            msg.append(0x00)
        }
        for i in (0..<8).reversed() {
            msg.append(UInt8((origLenBits >> (i * 8)) & 0xff))
        }

        // Process each 512-bit chunk
        for chunkStart in stride(from: 0, to: msg.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let j = chunkStart + i * 4
                w[i] = (UInt32(msg[j]) << 24) | (UInt32(msg[j+1]) << 16) |
                       (UInt32(msg[j+2]) << 8) | UInt32(msg[j+3])
            }
            for i in 16..<64 {
                let s0 = w[i-15].rotateRight(7) ^ w[i-15].rotateRight(18) ^ (w[i-15] >> 3)
                let s1 = w[i-2].rotateRight(17) ^ w[i-2].rotateRight(19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }

            var a = h0, b = h1, c = h2, d = h3
            var e = h4, f = h5, g = h6, h = h7

            for i in 0..<64 {
                let S1   = e.rotateRight(6) ^ e.rotateRight(11) ^ e.rotateRight(25)
                let ch   = (e & f) ^ (~e & g)
                let temp1 = h &+ S1 &+ ch &+ k[i] &+ w[i]
                let S0   = a.rotateRight(2) ^ a.rotateRight(13) ^ a.rotateRight(22)
                let maj  = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = S0 &+ maj

                h = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }

            h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d
            h4 = h4 &+ e; h5 = h5 &+ f; h6 = h6 &+ g; h7 = h7 &+ h
        }

        var digest = [UInt8]()
        for word in [h0, h1, h2, h3, h4, h5, h6, h7] {
            digest.append(UInt8((word >> 24) & 0xff))
            digest.append(UInt8((word >> 16) & 0xff))
            digest.append(UInt8((word >> 8) & 0xff))
            digest.append(UInt8(word & 0xff))
        }
        return digest
    }

    // MARK: - Crypto / Key Helpers

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

    private func extractRSAModulus(fromIdentity identity: SecIdentity?) -> Data? {
        guard let identity = identity else { return nil }
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        guard let certificate = cert else { return nil }
        let certData = SecCertificateCopyData(certificate) as Data
        return extractRSAModulusFromCertData(certData)
    }

    private func extractRSAModulusFromCertData(_ derData: Data) -> Data? {
        guard let cert = SecCertificateCreateWithData(nil, derData as CFData) else { return nil }

        var publicKey: SecKey?
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let _ = SecTrustCreateWithCertificates([cert] as CFArray, policy, &trust)

        if let trust = trust {
            if #available(iOS 14, *) {
                publicKey = SecTrustCopyKey(trust)
            } else {
                publicKey = SecTrustCopyPublicKey(trust)
            }
        }

        guard let key = publicKey else { return nil }

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else { return nil }

        // keyData es PKCS#1 DER: SEQUENCE { INTEGER(modulus), INTEGER(exponent) }
        return extractModulusFromPKCS1DER(keyData)
    }

    private func extractModulusFromPKCS1DER(_ der: Data) -> Data? {
        var idx = 0
        guard der.count > 2 else { return nil }

        // SEQUENCE tag 0x30
        guard der[idx] == 0x30 else { return nil }
        idx += 1
        let (_, seqLenBytes) = readDERLength(der, idx: idx)
        idx += seqLenBytes

        // INTEGER tag 0x02 (módulo)
        guard idx < der.count, der[idx] == 0x02 else { return nil }
        idx += 1

        let (modLen, modLenBytes) = readDERLength(der, idx: idx)
        idx += modLenBytes

        guard idx + modLen <= der.count else { return nil }

        var modulusData = der.subdata(in: idx..<(idx + modLen))
        // Eliminar byte de signo 0x00 si existe
        if modulusData.first == 0x00 {
            modulusData = modulusData.dropFirst()
        }
        return modulusData
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

// MARK: - UInt32 rotate helper

private extension UInt32 {
    func rotateRight(_ n: Int) -> UInt32 {
        return (self >> UInt32(n)) | (self << UInt32(32 - n))
    }
}
