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
}
