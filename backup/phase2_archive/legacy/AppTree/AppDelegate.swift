#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@main
#if canImport(UIKit)
class AppDelegate: UIResponder, UIApplicationDelegate {
#elseif canImport(AppKit)
class AppDelegate: NSObject, NSApplicationDelegate {
#endif

#if canImport(UIKit)
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Override point for customization after application launch.
        true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session
    }
#elseif canImport(AppKit)
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Override point for customization after application launch.
    }
#endif
}
