import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)

            // Create the CoreData container
            let container = PersistenceController.shared.container

            // Create the SwiftUI view with managedObjectContext
            let contentView = ContentView()
                .environment(\.managedObjectContext, container.viewContext)

            // Use a UIHostingController as window root view controller
            window.rootViewController = UIHostingController(rootView: contentView)

            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
