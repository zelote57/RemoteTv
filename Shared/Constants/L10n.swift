// L10n.swift — Strongly-typed localization catalog wrapper for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import Foundation

/// Type-safe namespace for localized string access across the application.
enum L10n {
    
    // MARK: - Connection & Pairing States
    enum Status {
        static var disconnected: String {
            return "status.disconnected".localized()
        }
        
        static var searching: String {
            return "status.searching".localized()
        }
        
        static var connecting: String {
            return "status.connecting".localized()
        }
        
        static var connected: String {
            return "status.connected".localized()
        }
        
        static var pairingRequired: String {
            return "status.pairing_required".localized()
        }
        
        static func error(_ description: String) -> String {
            return "status.error_prefix".localized(with: description)
        }
    }
    
    // MARK: - Navigation & Device Header
    enum Header {
        static var selectTv: String {
            return "header.select_tv".localized()
        }
        
        static var searchingTv: String {
            return "header.searching_tv".localized()
        }
        
        static var tvError: String {
            return "header.tv_error".localized()
        }
    }
    
    // MARK: - Polo v2 Pairing Dialog
    enum Pairing {
        static var dialogTitle: String {
            return "pairing.dialog_title".localized()
        }
        
        static func dialogMessage(deviceName: String) -> String {
            return "pairing.dialog_message".localized(with: deviceName)
        }
        
        static var pinPlaceholder: String {
            return "pairing.pin_placeholder".localized()
        }
        
        static var pairButton: String {
            return "pairing.pair_button".localized()
        }
        
        static var cancelButton: String {
            return "pairing.cancel_button".localized()
        }
    }
    
    // MARK: - Device Discovery & Picker Sheet
    enum Picker {
        static var title: String {
            return "picker.title".localized()
        }
        
        static var searching: String {
            return "picker.searching".localized()
        }
        
        static func deviceFormat(name: String) -> String {
            return "picker.device_format".localized(with: name)
        }
    }
    
    // MARK: - Common Actions & Alerts
    enum Common {
        static var ok: String {
            return "common.ok".localized()
        }
        
        static var cancel: String {
            return "common.cancel".localized()
        }
        
        static var errorTitle: String {
            return "common.error_title".localized()
        }
        
        static var retry: String {
            return "common.retry".localized()
        }
    }
}
