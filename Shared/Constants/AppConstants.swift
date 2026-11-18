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
        static let userLanguagePreference = "app_user_language_preference"
        
        /// Returns the persistence key for a specific TV host pairing status
        static func isPairedKey(for host: String) -> String {
            return "\(tvPairedPrefix)\(host)"
        }
    }

    // MARK: - External Links
    enum Links {
        static let gitHubRepository = "https://github.com/zelote57/RemoteTv"
    }

    // MARK: - UI Metrics & Dimensions (Stitch Design & iPhone 6 Plus 414 x 736 pt target)
    enum UI {
        static let dpadDiameter: CGFloat = 280.0
        static let dpadCenterRatio: CGFloat = 120.0 / 280.0
        
        static let actionButtonSize: CGFloat = 70.0
        static let headerButtonSize: CGFloat = 44.0
        
        static let headerHeight: CGFloat = 48.0
        static let headerHorizontalInset: CGFloat = 16.0
        static let headerTopOffset: CGFloat = 14.0
        static let headerActionsSpacing: CGFloat = 8.0
        
        static let actionsRowSpacing: CGFloat = 36.0
        static let centerVerticalOffset: CGFloat = 20.0
        static let standbyControlAlpha: CGFloat = 0.35
        
        static let statusDotDiameter: CGFloat = 8.0
        static let defaultAnimationDuration: TimeInterval = 0.25
    }
}
