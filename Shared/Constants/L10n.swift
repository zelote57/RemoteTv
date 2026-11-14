// L10n.swift — Strongly-typed localization catalog wrapper for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import Foundation

/// Type-safe namespace for localized string access across the application.
enum L10n {
    
    // MARK: - Connection & Pairing States
    enum Status {
        static var disconnected: String {
            return "status.disconnected".localized
        }
        
        static var searching: String {
            return "status.searching".localized
        }
        
        static var connecting: String {
            return "status.connecting".localized
        }
        
        static var connected: String {
            return "status.connected".localized
        }
        
        static var pairingRequired: String {
            return "status.pairing_required".localized
        }
        
        static func error(_ description: String) -> String {
            return "status.error_prefix".localizedFormat(description)
        }
    }
    
    // MARK: - Navigation & Device Header
    enum Header {
        static var selectTv: String {
            return "header.select_tv".localized
        }
        
        static var searchingTv: String {
            return "header.searching_tv".localized
        }
        
        static var tvError: String {
            return "header.tv_error".localized
        }
    }
    
    // MARK: - Polo v2 Pairing Dialog
    enum Pairing {
        static var dialogTitle: String {
            return "pairing.dialog_title".localized
        }
        
        static func dialogMessage(deviceName: String) -> String {
            return "pairing.dialog_message".localizedFormat(deviceName)
        }
        
        static var pinPlaceholder: String {
            return "pairing.pin_placeholder".localized
        }
        
        static var pairButton: String {
            return "pairing.pair_button".localized
        }
        
        static var cancelButton: String {
            return "pairing.cancel_button".localized
        }
    }
    
    // MARK: - Device Discovery & Picker Sheet
    enum Picker {
        static var title: String {
            return "picker.title".localized
        }
        
        static var searching: String {
            return "picker.searching".localized
        }
        
        static func deviceFormat(name: String) -> String {
            return "picker.device_format".localizedFormat(name)
        }

        static var wifiBadge: String {
            return "picker.wifi_badge".localized
        }

        static func detectedCount(_ count: Int) -> String {
            return "picker.detected_count".localizedFormat(count)
        }

        static var scanningLocalNetwork: String {
            return "picker.scanning_local_network".localized
        }

        static var activeSearch: String {
            return "picker.active_search".localized
        }

        static var searchCompleted: String {
            return "picker.search_completed".localized
        }

        static var currentBadge: String {
            return "picker.current_badge".localized
        }

        static var connectedStatus: String {
            return "picker.connected_status".localized
        }

        static var availableStatus: String {
            return "picker.available_status".localized
        }

        static var scanAgain: String {
            return "picker.scan_again".localized
        }

        static var retrySearch: String {
            return "picker.retry_search".localized
        }

        static var connectManualIP: String {
            return "picker.connect_manual_ip".localized
        }

        static var emptyTitle: String {
            return "picker.empty_title".localized
        }

        static var emptyDescription: String {
            return "picker.empty_description".localized
        }

        static var troubleshootingTitle: String {
            return "picker.troubleshooting_title".localized
        }

        static var tipWifiTitle: String {
            return "picker.tip_wifi_title".localized
        }

        static var tipWifiDesc: String {
            return "picker.tip_wifi_desc".localized
        }

        static var tipPermissionTitle: String {
            return "picker.tip_permission_title".localized
        }

        static var tipPermissionDesc: String {
            return "picker.tip_permission_desc".localized
        }

        static var tipPowerTitle: String {
            return "picker.tip_power_title".localized
        }

        static var tipPowerDesc: String {
            return "picker.tip_power_desc".localized
        }

        static var manualIpTitle: String {
            return "picker.manual_ip_title".localized
        }

        static var manualIpMessage: String {
            return "picker.manual_ip_message".localized
        }

        static var manualIpPlaceholder: String {
            return "picker.manual_ip_placeholder".localized
        }

        static var manualIpConnect: String {
            return "picker.manual_ip_connect".localized
        }
    }
    
    // MARK: - Common Actions & Alerts
    enum Common {
        static var ok: String {
            return "common.ok".localized
        }
        
        static var cancel: String {
            return "common.cancel".localized
        }
        
        static var errorTitle: String {
            return "common.error_title".localized
        }
        
        static var retry: String {
            return "common.retry".localized
        }
    }
}
