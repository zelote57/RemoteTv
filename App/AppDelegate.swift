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
        
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("[App] Pasando a segundo plano — cerrando conexiones de red activas")
        GoogleTVClient.shared.disconnect()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("[App] Regresando a primer plano — reactivando control")
        GoogleTVClient.shared.startAutoDiscovery()
    }
}
