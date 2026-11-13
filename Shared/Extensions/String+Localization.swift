// String+Localization.swift — Type-safe localization extension for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import Foundation

extension String {
    
    /// Returns the localized string for this key using standard main bundle.
    /// - Parameters:
    ///   - tableName: The name of the strings table to search, defaults to "Localizable".
    ///   - bundle: The bundle containing the table, defaults to Bundle.main.
    ///   - comment: Developer comment for context, defaults to empty.
    /// - Returns: Localized string representation.
    func localized(tableName: String? = nil, bundle: Bundle = .main, comment: String = "") -> String {
        return NSLocalizedString(self, tableName: tableName, bundle: bundle, value: self, comment: comment)
    }
    
    /// Returns the formatted localized string by applying arguments to the localized key format.
    /// - Parameter arguments: Format arguments matching the format specifiers in the string.
    /// - Returns: Formatted localized string.
    func localized(with arguments: CVarArg...) -> String {
        let format = localized()
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
