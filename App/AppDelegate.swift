// AppDelegate.swift — Application lifecycle coordinator for RemoteTv
// Fully compliant with Swift 5.0 and iOS 12.0+ (Single-window architecture, no SceneDelegate)

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        let remoteVC = RemoteViewController()
        window.rootViewController = remoteVC
        window.backgroundColor = Theme.Colors.background
        window.makeKeyAndVisible()
        self.window = window
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: Theme.themeDidChangeNotification,
            object: nil
        )
        
        return true
    }

    @objc private func handleThemeChanged() {
        window?.backgroundColor = Theme.Colors.background
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        GoogleTVClient.shared.disconnect()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        GoogleTVClient.shared.startAutoDiscovery()
    }
}
