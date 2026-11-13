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
    private let port: Int = Int(GoogleTVPorts.remote)

    private var readBuffer = Data()
    private var isConnected = false
    private var sequenceNumber: Int = 1

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
        let downMsg = buildKeyEventMessage(keyCode: keyCode, isDown: true)
        send(data: downMsg)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let upMsg = self.buildKeyEventMessage(keyCode: keyCode, isDown: false)
            self.send(data: upMsg)
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
            delegate?.remoteServiceDidDisconnect(error: "No se pudo crear el socket hacia \(host):\(port)")
            return
        }

        let unmanagedRead = r.takeRetainedValue()
        let unmanagedWrite = w.takeRetainedValue()

        guard let identity = CertificateStore.getClientIdentity() else {
            print("[Remote] Error: Sin certificado de cliente")
            delegate?.remoteServiceDidDisconnect(error: "No se pudo cargar el certificado de cliente (OSStatus \(CertificateStore.lastError))")
            return
        }

        let certArray: NSArray = [identity]
        let settings: NSDictionary = [
            kCFStreamSSLIsServer: kCFBooleanFalse as Any,
            kCFStreamSSLValidatesCertificateChain: kCFBooleanFalse as Any,
            kCFStreamSSLCertificates: certArray,
        ]

        CFReadStreamSetProperty(unmanagedRead, CFStreamPropertyKey(kCFStreamPropertySSLSettings), settings)
        CFWriteStreamSetProperty(unmanagedWrite, CFStreamPropertyKey(kCFStreamPropertySSLSettings), settings)

        let inStream  = unmanagedRead as InputStream
        let outStream = unmanagedWrite as OutputStream

        inStream.delegate  = self
        outStream.delegate = self
        inStream.schedule(in: .main, forMode: .common)
        outStream.schedule(in: .main, forMode: .common)
        inStream.open()
        outStream.open()

        inputStream  = inStream
        outputStream = outStream

        print("[Remote] Streams abiertos hacia \(host):\(port)")
    }

    // MARK: - StreamDelegate

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream === outputStream {
                isConnected = true
                print("[Remote] Conectado al puerto de control \(port)")
                DispatchQueue.main.async { self.delegate?.remoteServiceDidConnect() }
            }

        case .hasBytesAvailable:
            readAvailableBytes()

        case .errorOccurred:
            let err = aStream.streamError?.localizedDescription ?? "Error desconocido"
            print("[Remote] Error: \(err)")
            isConnected = false
            DispatchQueue.main.async { self.delegate?.remoteServiceDidDisconnect(error: err) }

        case .endEncountered:
            print("[Remote] Conexión cerrada por el TV")
            isConnected = false
            DispatchQueue.main.async { self.delegate?.remoteServiceDidDisconnect(error: nil) }

        default:
            break
        }
    }

    // MARK: - Lectura

    private func readAvailableBytes() {
        let bufSize = 4096
        var buf = [UInt8](repeating: 0, count: bufSize)
        while let stream = inputStream, stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: bufSize)
            if n > 0 {
                readBuffer.append(contentsOf: buf[0..<n])
            } else { break }
        }
        readBuffer.removeAll()
    }

    // MARK: - Protobuf KeyEvent

    private func buildKeyEventMessage(keyCode: AndroidKeyCode, isDown: Bool) -> Data {
        let direction = isDown ? 1 : 2  // KEY_DOWN=1, KEY_UP=2

        var inner = Data()
        inner.append(protoVarint(field: 1, value: keyCode.rawValue))
        inner.append(protoVarint(field: 2, value: direction))

        var outer = Data()
        outer.append(protoVarint(field: 1, value: sequenceNumber))
        outer.append(protoBytes(field: 12, value: inner))
        sequenceNumber += 1

        return delimited(outer)
    }

    // MARK: - Envío

    private func send(data: Data) {
        guard let stream = outputStream, stream.hasSpaceAvailable else { return }
        let bytes = [UInt8](data)
        stream.write(bytes, maxLength: bytes.count)
    }

    // MARK: - Protobuf Helpers

    private func protoVarint(field: Int, value: Int) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64(bitPattern: Int64(field << 3 | 0))))
        d.append(encodeVarint(UInt64(bitPattern: Int64(value))))
        return d
    }

    private func protoBytes(field: Int, value: Data) -> Data {
        var d = Data()
        d.append(encodeVarint(UInt64(bitPattern: Int64(field << 3 | 2))))
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
