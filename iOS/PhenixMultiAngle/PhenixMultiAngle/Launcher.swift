//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixCore
import UIKit

/// Have all instructions how to initiate application dependencies and the main coordinator
class Launcher {
    private let queue: DispatchQueue
    private let window: UIWindow?
    private let deeplink: PhenixDeeplinkModel?

    init(window: UIWindow, deeplink: PhenixDeeplinkModel? = nil) {
        self.queue = DispatchQueue.global(qos: .userInitiated)
        self.window = window
        self.deeplink = deeplink
    }

    /// Starts all necessary application processes
    /// - Returns: Main coordinator which reference must  be saved
    func start(completion: @escaping (MainCoordinator) -> Void) {
        os_log(.debug, log: .launcher, "Launcher started")

        // Create launch view controller, which will hide all async loading
        let vc = LaunchViewController.instantiate()

        // Create navigation controller
        let nc = UINavigationController(rootViewController: vc)
        nc.isNavigationBarHidden = true
        nc.navigationBar.isTranslucent = false

        // Display the navigation controller holding screen
        // which looks the same as the launch screen.
        window?.rootViewController = nc
        window?.makeKeyAndVisible()

        // Prepare all the necessary components on a background queue
        // to not block the main thread.
        queue.async {
            // Keep a strong reference so that the Launcher would not be deallocated too quickly.

            let unrecoverableErrorHandler: (String?) -> Void = { description in
                DispatchQueue.main.async {
                    AppDelegate.terminate(
                        afterDisplayingAlertWithTitle: "Something went wrong!",
                        message:
                            """
                            Application entered in unrecoverable state \
                            and will be terminated (\(description ?? "N/A")).
                            """
                    )
                }
            }

            let configuration: PhenixConfiguration = {
                let current = PhenixConfiguration.default

                guard let deeplink = self.deeplink else {
                    return current
                }

                let configuration = PhenixConfiguration(
                    backend: deeplink.backend ?? current.backend,
                    edgeToken: deeplink.edgeToken ?? current.edgeToken,
                    pcast: deeplink.uri ?? current.pcast,
                    capabilities: current.capabilities,
                    channelAliases: deeplink.channelAliases ?? current.channelAliases,
                    streamTokens: deeplink.streamTokens ?? current.streamTokens,
                    logLevel: .off
                )

                return configuration
            }()

            os_log(.debug, log: .launcher, "Deeplink model: %{private}s", String(describing: self.deeplink))
            os_log(.debug, log: .launcher, "Configuration: %{private}s", String(describing: configuration))

            // Configure necessary object instances
            os_log(.debug, log: .launcher, "Configure Phenix instance")

            let manager = PhenixManager(configuration: configuration)
            manager.start(unrecoverableErrorCompletion: unrecoverableErrorHandler)

            // Create dependencies
            os_log(.debug, log: .launcher, "Create Dependency container")
            let container = DependencyContainer(phenixManager: manager)

            os_log(.debug, log: .launcher, "Start main coordinator")

            let coordinator = MainCoordinator(
                navigationController: nc,
                dependencyContainer: container,
                channelAliases: configuration.channelAliases,
                streamTokens: configuration.streamTokens
            )

            DispatchQueue.main.async {
                coordinator.start()
                completion(coordinator)
            }
        }
    }
}

