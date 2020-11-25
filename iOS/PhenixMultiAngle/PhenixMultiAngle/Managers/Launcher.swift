//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixCore
import UIKit

/// Have all instructions how to initiate application dependencies and the main coordinator
class Launcher {
    private let deeplink: DeeplinkModel?
    private weak var window: UIWindow?

    init(window: UIWindow, deeplink: DeeplinkModel? = nil) {
        self.window = window
        self.deeplink = deeplink
    }

    /// Starts all necessary application processes
    /// - Returns: Main coordinator which reference must  be saved
    func start(completion: @escaping (MainCoordinator) -> Void) {
        os_log(.debug, log: .launcher, "Launcher started")
        defer {
            os_log(.debug, log: .launcher, "Launcher finished")
        }

        // Create launch view controller, which will hide all async loading
        let vc = LaunchViewController.instantiate()

        // Create navigation controller
        let nc = UINavigationController(rootViewController: vc)
        nc.isNavigationBarHidden = true
        nc.navigationBar.isTranslucent = false

        window?.rootViewController = nc
        window?.makeKeyAndVisible()

        DispatchQueue.global(qos: .userInitiated).async {
            // Keep a strong reference so that the Launcher would not be deallocated too quickly.

            // Configure necessary object instances
            os_log(.debug, log: .launcher, "Configure Phenix instance")

            let backend = self.deeplink?.backend ?? PhenixConfiguration.backend
            let pcast = self.deeplink?.uri ?? PhenixConfiguration.pcast

            let manager = PhenixManager(backend: backend, pcast: pcast)
            manager.start { [weak nc] description in
                // Unrecoverable Error Completion
                let reason = description ?? "N/A"
                let alert = UIAlertController(title: "Error", message: "Phenix SDK reached unrecoverable error: (\(reason))", preferredStyle: .alert)
                alert.addAction(
                    UIAlertAction(title: "Close app", style: .destructive) { _ in
                        fatalError("Unrecoverable error: \(String(describing: description))")
                    }
                )

                nc?.presentedViewController?.dismiss(animated: false)
                nc?.present(alert, animated: true)
            }

            // Create dependencies
            os_log(.debug, log: .launcher, "Create Dependency container")
            let container = DependencyContainer(phenixManager: manager)

            os_log(.debug, log: .launcher, "Start main coordinator")
            os_log(.debug, log: .launcher, "Deeplink model: %{private}s", String(describing: self.deeplink))
            let channelAliases = self.deeplink?.channelAliases ?? PhenixConfiguration.channelAliases
            let coordinator = MainCoordinator(navigationController: nc, dependencyContainer: container, channelAliases: channelAliases)

            DispatchQueue.main.async {
                coordinator.start()
                completion(coordinator)
            }
        }
    }
}

