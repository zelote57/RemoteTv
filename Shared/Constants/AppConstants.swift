// AppConstants.swift — Centralized domain constants for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import UIKit

/// Caseless root enum serving as a namespace for all static constants.
/// Zero magic numbers or strings across the entire codebase.
enum AppConstants {

    // MARK: - Network Domain Constants
    enum Network {
        /// Google TV v2 TLS pairing port (Polo v2 protocol)
        static let pairingPort: UInt16 = 6467
        
        /// Google TV v2 TLS remote control port (KeyEvent & status protocol)
        static let remoteControlPort: UInt16 = 6466
        
        /// Google Cast HTTP Eureka info discovery port
        static let castProbePort: UInt16 = 8008
        
        /// Standard mDNS service type for Android TV Remote v2
        static let mdnsServiceTypeRemote = "_androidtvremote2._tcp."
        
        /// Standard mDNS service type for Google Cast devices
        static let mdnsServiceTypeCast = "_googlecast._tcp."
        
        /// Local network discovery domain
        static let mdnsLocalDomain = "local."
        
        /// Known direct fallback IP for the local target TV
        static let targetDeviceFallbackIP = "192.168.100.175"
        
        /// Default network request and pairing step timeout in seconds
        static let defaultTimeoutSeconds: TimeInterval = 10.0
        
        /// Socket read buffer chunk size in bytes
        static let socketBufferSize: Int = 4096
        
        /// Keep-alive ping interval in seconds
        static let pingIntervalSeconds: TimeInterval = 5.0
        
        /// Polo protocol client service identification name
        static let serviceName = "atvremote"
        
        /// Client device display name presented to the television
        static let clientDisplayName = "Remote TV"
        
        /// Client software version string transmitted during handshake
        static let clientAppVersion = "1.0.0"
        
        /// Active feature bitmask for remote control capabilities (code1 = 611)
        /// Represents PING(1) | KEY(2) | POWER(32) | VOLUME(64) | APP_LINK(512)
        static let activeFeaturesCode: Int = 611
    }

    // MARK: - Storage Keys (UserDefaults)
    enum StorageKeys {
        static let savedTvName = "saved_tv_name"
        static let savedTvHost = "saved_tv_ip"
        static let tvPairedPrefix = "tv_paired_"
        static let appThemeMode = "app_theme_mode"
        
        /// Returns the persistence key for a specific TV host pairing status
        static func isPairedKey(for host: String) -> String {
            return "\(tvPairedPrefix)\(host)"
        }
    }

    // MARK: - KeyCodes Domain (Android TV / Google TV KeyEvent mapping)
    enum KeyCodes: Int {
        case dpadUp = 19
        case dpadDown = 20
        case dpadLeft = 21
        case dpadRight = 22
        case dpadCenter = 23
        
        case back = 4
        case home = 3
        case menu = 82
        case search = 84
        
        case volumeUp = 24
        case volumeDown = 25
        case volumeMute = 164
        
        case power = 26
        case mediaPlayPause = 85
        case mediaNext = 87
        case mediaPrevious = 88
        
        case channelUp = 166
        case channelDown = 167
        case tvInput = 178
        case assistant = 219
        
        /// Direction short press code for Google TV v2 RemoteKeyInject
        static let directionShort: Int = 3
        static let directionStartLong: Int = 1
        static let directionEndLong: Int = 2
    }

    // MARK: - UI Metrics & Dimensions (iPhone 6 Plus 414 x 736 pt target)
    enum UI {
        static let dpadDiameter: CGFloat = 268.0
        static let dpadCenterRatio: CGFloat = 0.42
        
        static let actionButtonSize: CGFloat = 72.0
        static let powerButtonSize: CGFloat = 46.0
        static let themeToggleButtonSize: CGFloat = 40.0
        static let pickerChevronSize: CGFloat = 44.0
        
        static let headerHeight: CGFloat = 48.0
        static let headerHorizontalInset: CGFloat = 20.0
        static let headerTopOffset: CGFloat = 16.0
        
        static let actionsRowSpacing: CGFloat = 32.0
        static let actionsRowTopSpacing: CGFloat = 46.0
        static let centerVerticalOffset: CGFloat = 28.0
        
        static let statusDotDiameter: CGFloat = 7.0
        static let borderWidthStandard: CGFloat = 1.0
        static let defaultAnimationDuration: TimeInterval = 0.25
    }
}
