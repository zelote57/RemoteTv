// RemoteService.swift — Google TV Remote Protocol (puerto 6467)
// Envía KeyEvents via mTLS usando remotemessage.proto (proto3)
// Compatible con iOS 12 — CFStream + TLS

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
    private let port: Int = 6467

    private var readBuffer = Data()
    private var isConnected = false

    // MARK: - API Pública

    func connect(host: String) {
        guard !isConnected else { return }
        self.host = host
        openTLSStreams()
    }

    func sendKey(_ keyCode: AndroidKeyCode) {
        guard isConnected else {
            print("[Remote] No conectado — ignorando tecla \(keyCode)")
            return
        }
        // Enviar KEY_DOWN
        let downMsg = buildKeyEventMessage(keyCode: keyCode, isDown: true)
        send(data: downMsg)

        // Enviar KEY_UP con un pequeño delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let upMsg = self?.buildKeyEventMessage(keyCode: keyCode, isDown: false)
            if let msg = upMsg { self?.send(data: msg) }
        }
        print("[Remote] KeyEvent \(keyCode) (\(keyCode.rawValue)) enviado")
    }

    func disconnect() {
        isConnected = false
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil
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
            delegate?.remoteServiceDidDisconnect(error: "No se pudo crear el socket de control")
            return
        }

        inputStream  = r.takeRetainedValue()
        outputStream = w.takeRetainedValue()

        guard let identity = CertificateStore.getClientIdentity() else {
            delegate?.remoteServiceDidDisconnect(error: "Certificado de cliente no disponible")
            return
        }

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

        print("[Remote] Streams abiertos hacia \(host):\(port)")
    }

    // MARK: - StreamDelegate

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream === outputStream {
                isConnected = true
                print("[Remote] Conectado al puerto de control \(port)")
                delegate?.remoteServiceDidConnect()
            }

        case .hasBytesAvailable:
            readAvailableBytes()

        case .errorOccurred:
            let err = aStream.streamError?.localizedDescription ?? "Error"
            print("[Remote] Error: \(err)")
            isConnected = false
            delegate?.remoteServiceDidDisconnect(error: err)

        case .endEncountered:
            print("[Remote] Conexión cerrada por el TV")
            isConnected = false
            delegate?.remoteServiceDidDisconnect(error: nil)

        default:
            break
        }
    }

    // MARK: - Lectura (keep-alive / mensajes del servidor)

    private func readAvailableBytes() {
        let bufSize = 4096
        var buf = [UInt8](repeating: 0, count: bufSize)
        while let stream = inputStream, stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: bufSize)
            if n > 0 {
                readBuffer.append(contentsOf: buf[0..<n])
            } else { break }
        }
        // No procesamos mensajes entrantes del canal de control por ahora
        readBuffer.removeAll()
    }

    // MARK: - Protobuf KeyEvent (remotemessage.proto)

    // RemoteMessage (outer):
    //   field 1 (sequence_number, varint) = auto-increment
    //   field 12 (remote_key_inject, embedded message)
    //
    // RemoteKeyInject:
    //   field 1 (key_code, varint)
    //   field 2 (direction, varint)  — KEY_DOWN = 1, KEY_UP = 2

    private var sequenceNumber: Int = 1

    private func buildKeyEventMessage(keyCode: AndroidKeyCode, isDown: Bool) -> Data {
        let direction = isDown ? 1 : 2  // KEY_DOWN=1, KEY_UP=2

        // Inner RemoteKeyInject
        var inner = Data()
        inner.append(protoVarint(field: 1, value: keyCode.rawValue))
        inner.append(protoVarint(field: 2, value: direction))

        // Outer RemoteMessage
        var outer = Data()
        outer.append(protoVarint(field: 1, value: sequenceNumber))
        outer.append(protoBytes(field: 12, value: inner))
        sequenceNumber += 1

        return delimited(outer)
    }

    // MARK: - Envío

    private func send(data: Data) {
        guard let stream = outputStream, stream.hasSpaceAvailable else { return }
        data.withUnsafeBytes { ptr in
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
}
