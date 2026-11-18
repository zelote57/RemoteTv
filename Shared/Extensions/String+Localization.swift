// String+Localization.swift — Type-safe dynamic localization extension for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import Foundation

extension String {
    
    /// Returns the localized string for this key using active LocalizationManager bundle.
    var localized: String {
        return LocalizationManager.shared.localizedString(forKey: self)
    }
    
    /// Returns the localized string for this key with custom table or bundle parameters.
    func localized(tableName: String? = nil, bundle: Bundle? = nil, comment: String = "") -> String {
        if let bundle = bundle {
            return NSLocalizedString(self, tableName: tableName, bundle: bundle, value: self, comment: comment)
        }
        return LocalizationManager.shared.localizedString(forKey: self)
    }
    
    /// Returns the formatted localized string by applying arguments to the localized key format.
    func localizedFormat(_ arguments: CVarArg...) -> String {
        return LocalizationManager.shared.localizedFormat(forKey: self, arguments: arguments)
    }
}
