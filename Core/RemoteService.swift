// RemoteService.swift — Google TV Remote Protocol v2 (puerto 6466)
// Implementación completa del protocolo de control remoto Android TV Remote v2
// Handshake: remote_configure (f1) → remote_set_active (f2) → remote_start (f40)
// Keep-Alive: responde automáticamente a remote_ping_request (f8) con remote_ping_response (f9)
// Inyección de teclas: remote_key_inject (f10) con dirección SHORT (3)
// Compatible con iOS 12 puro (CFStream + TLS + Protobuf nativo)

import Foundation
import Security

// MARK: - Delegate

protocol RemoteServiceDelegate: AnyObject {
    func remoteServiceDidConnect()
    func remoteServiceDidDisconnect(error: String?)
}

// MARK: - RemoteService

class RemoteService: NSObject, StreamDelegate {

    weak var delegate: RemoteServiceDelegate?

    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private var host: String = ""
    private let port: Int = Int(GoogleTVPorts.remote) // 6466

    private var readBuffer = Data()
    private var pendingWriteData = Data()
    private(set) var isReady = false

    private enum HandshakeState {
        case idle, connecting, receivedConfigure, active
    }
    private var handshakeState: HandshakeState = .idle

    // MARK: - API Pública

    func connect(host: String) {
        if isReady && self.host == host {
            print("[Remote] Ya conectado y listo hacia \(host)")
            return
        }
        disconnect()
        self.host = host
        self.handshakeState = .connecting
        self.isReady = false
        self.readBuffer = Data()
        self.pendingWriteData = Data()
        openTLSStreams()
    }

    func sendKey(_ keyCode: AndroidKeyCode) {
        guard isReady else {
            print("[Remote] Canal no listo — intentando conectar y encolando tecla \(keyCode)")
            if handshakeState == .idle && !host.isEmpty {
                connect(host: host)
            }
            return
        }

        // remote_key_inject (field 10):
        //   field 1 (key_code): int (enum)
        //   field 2 (direction): 3 (SHORT)
        var inner = Data()
        inner.append(protoVarint(field: 1, value: keyCode.rawValue))
        inner.append(protoVarint(field: 2, value: 3)) // RemoteDirection.SHORT = 3

        var outer = Data()
        outer.append(protoBytes(field: 10, value: inner)) // remote_key_inject = 10

        send(data: delimited(outer))
        print("[Remote] 🎮 Tecla enviada: \(keyCode) (código \(keyCode.rawValue), SHORT)")
    }

    func disconnect() {
        isReady = false
        handshakeState = .idle
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .main, forMode: .common)
        outputStream?.remove(from: .main, forMode: .common)
        inputStream?.delegate = nil
        outputStream?.delegate = nil
        inputStream = nil
        outputStream = nil
        readBuffer.removeAll()
        pendingWriteData.removeAll()
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
            notifyDisconnect(error: "No se pudo crear el socket hacia \(host):\(port)")
            return
        }

        let readStream = r.takeRetainedValue()
        let writeStream = w.takeRetainedValue()

        guard let identity = CertificateStore.getClientIdentity() else {
            print("[Remote] Error: Sin certificado de cliente")
            notifyDisconnect(error: "Error certificado cliente (OSStatus \(CertificateStore.lastError))")
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

        print("[Remote] Streams TLS abriéndose hacia \(host):\(port)…")
    }

    // MARK: - StreamDelegate

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream === outputStream {
                print("[Remote] Socket TLS conectado a puerto 6466 — esperando remote_configure del TV")
                flushPendingData()
            }

        case .hasBytesAvailable:
            if aStream === inputStream {
                readAvailableBytes()
            }

        case .hasSpaceAvailable:
            if aStream === outputStream {
                flushPendingData()
            }

        case .errorOccurred:
            let err = aStream.streamError as NSError?
            let msg = err?.localizedDescription ?? "Error desconocido"
            let code = err?.code ?? 0
            print("[Remote] Error en stream: \(msg) (Code \(code))")
            notifyDisconnect(error: msg)

        case .endEncountered:
            print("[Remote] Conexión cerrada por el TV")
            notifyDisconnect(error: nil)

        default:
            break
        }
    }

    // MARK: - Lectura y Procesamiento de Mensajes

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
            guard readBuffer.count >= total else { break } // Espera el paquete completo
            let msgData = readBuffer.subdata(in: off..<total)
            readBuffer.removeSubrange(0..<total)
            handleTVMessage(msgData)
        }
    }

    private func handleTVMessage(_ data: Data) {
        let fields = protoParseFields(data)
        let keys = fields.keys.sorted()
        print("[Remote] ← TV envió mensaje (\(data.count) bytes, campos: \(keys))")

        // 1. remote_configure (field 1)
        if fields[1] != nil {
            print("[Remote] ← Recibido remote_configure — enviando respuesta de configuración")
            sendConfigureReply()
            handshakeState = .receivedConfigure
        }

        // 2. remote_set_active (field 2)
        if fields[2] != nil {
            print("[Remote] ← Recibido remote_set_active — enviando confirmación de activación")
            sendSetActiveReply()
            markReady()
        }

        // 3. remote_start (field 40)
        if fields[40] != nil {
            print("[Remote] ← Recibido remote_start — ¡Canal de control totalmente listo!")
            markReady()
        }

        // 4. remote_set_volume_level (field 50)
        if fields[50] != nil {
            print("[Remote] ← Recibido estado de volumen del TV")
            markReady()
        }

        // 5. remote_ping_request (field 8) → Responder de inmediato con remote_ping_response (field 9)
        if let pingData = fields[8] {
            var val1 = 0
            let pingFields = protoParseFields(pingData)
            if let v1Data = pingFields[1] {
                var off = 0
                val1 = Int(varintDecode(v1Data, offset: &off) ?? 0)
            }
            sendPingResponse(val1: val1)
        }
    }

    private func markReady() {
        guard !isReady else { return }
        isReady = true
        handshakeState = .active
        print("[Remote] ✅ Canal de control activo y sincronizado")
        DispatchQueue.main.async { self.delegate?.remoteServiceDidConnect() }
    }

    // MARK: - Respuestas del Handshake

    private func sendConfigureReply() {
        // device_info sub-message:
        //   field 3 (unknown1): 1
        //   field 4 (unknown2): "1"
        //   field 5 (package_name): "atvremote"
        //   field 6 (app_version): "1.0.0"
        var devInfo = Data()
        devInfo.append(protoVarint(field: 3, value: 1))
        devInfo.append(protoString(field: 4, value: "1"))
        devInfo.append(protoString(field: 5, value: "atvremote"))
        devInfo.append(protoString(field: 6, value: "1.0.0"))

        // remote_configure:
        //   field 1 (code1): 611 (características activas)
        //   field 2 (device_info): sub-message
        var configMsg = Data()
        configMsg.append(protoVarint(field: 1, value: 611))
        configMsg.append(protoBytes(field: 2, value: devInfo))

        var outer = Data()
        outer.append(protoBytes(field: 1, value: configMsg)) // remote_configure = 1

        send(data: delimited(outer))
        print("[Remote] → Enviado remote_configure reply (code1: 611)")
    }

    private func sendSetActiveReply() {
        // remote_set_active:
        //   field 1 (active): 611
        var activeMsg = Data()
        activeMsg.append(protoVarint(field: 1, value: 611))

        var outer = Data()
        outer.append(protoBytes(field: 2, value: activeMsg)) // remote_set_active = 2

        send(data: delimited(outer))
        print("[Remote] → Enviado remote_set_active reply (active: 611)")
    }

    private func sendPingResponse(val1: Int) {
        // remote_ping_response:
        //   field 1 (val1): val1 del request
        var pingResp = Data()
        pingResp.append(protoVarint(field: 1, value: val1))

        var outer = Data()
        outer.append(protoBytes(field: 9, value: pingResp)) // remote_ping_response = 9

        send(data: delimited(outer))
    }

    // MARK: - Envío con Buffer

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
            } else {
                break
            }
        }
    }

    private func notifyDisconnect(error: String?) {
        let wasReady = isReady
        isReady = false
        handshakeState = .idle
        if wasReady {
            print("[Remote] Desconectado del TV: \(error ?? "normal")")
        }
        DispatchQueue.main.async { self.delegate?.remoteServiceDidDisconnect(error: error) }
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
                guard varintDecode(data, offset: &o2) != nil else { return fields }
                fields[fieldNum] = data.subdata(in: idx..<o2); idx = o2
            case 2:
                var o2 = idx
                guard let len = varintDecode(data, offset: &o2) else { return fields }
                let end = o2 + Int(len)
                guard end <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: o2..<end); idx = end
            case 1:
                guard idx + 8 <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: idx..<(idx+8)); idx += 8
            case 5:
                guard idx + 4 <= data.count else { return fields }
                fields[fieldNum] = data.subdata(in: idx..<(idx+4)); idx += 4
            default:
                return fields
            }
        }
        return fields
    }
}
