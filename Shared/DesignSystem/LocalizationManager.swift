// LocalizationManager.swift — Dynamic in-app language manager for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+

import Foundation

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case spanish = "es"
    case english = "en"
    
    var identifier: String {
        return self.rawValue
    }
}

// MARK: - LocalizationManager

class LocalizationManager {

    static let shared = LocalizationManager()
    
    static let languageDidChangeNotification = Notification.Name("RemoteTvLanguageDidChangeNotification")
    private let storageKey = AppConstants.StorageKeys.userLanguagePreference
    
    private(set) var currentLanguage: AppLanguage = .system
    private var bundle: Bundle = .main
    
    private init() {
        loadSavedLanguage()
    }
    
    private func loadSavedLanguage() {
        if let savedCode = UserDefaults.standard.string(forKey: storageKey),
           let language = AppLanguage(rawValue: savedCode) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        updateBundle()
    }
    
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        self.currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        updateBundle()
        
        NotificationCenter.default.post(name: LocalizationManager.languageDidChangeNotification, object: nil)
    }
    
    private func updateBundle() {
        switch currentLanguage {
        case .system:
            self.bundle = .main
        case .spanish, .english:
            if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
               let customBundle = Bundle(path: path) {
                self.bundle = customBundle
            } else {
                self.bundle = .main
            }
        }
    }
    
    func localizedString(forKey key: String, fallback: String? = nil) -> String {
        return bundle.localizedString(forKey: key, value: fallback ?? key, table: nil)
    }
    
    func localizedFormat(forKey key: String, arguments: [CVarArg]) -> String {
        let format = localizedString(forKey: key)
        let locale: Locale
        switch currentLanguage {
        case .system:
            locale = Locale.current
        case .spanish:
            locale = Locale(identifier: "es")
        case .english:
            locale = Locale(identifier: "en")
        }
        return String(format: format, locale: locale, arguments: arguments)
    }
}
