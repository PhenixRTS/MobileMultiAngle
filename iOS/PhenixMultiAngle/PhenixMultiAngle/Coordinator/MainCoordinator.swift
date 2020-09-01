//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixCore
import UIKit

class MainCoordinator: Coordinator {
    let navigationController: UINavigationController
    private(set) var childCoordinators = [Coordinator]()
    private let dependencyContainer: DependencyContainer

    private var phenixManager: PhenixManager { dependencyContainer.phenixManager }

    init(navigationController: UINavigationController, dependencyContainer: DependencyContainer) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }

    func start() {
        os_log(.debug, log: .coordinator, "Main coordinator started")

        // Get default channel aliases
        let channelAliases = PhenixConfiguration.channelAliases

        var channels: [Channel] = []

        // Convert aliases into channel models
        for alias in channelAliases {
            let channel = Channel(alias: alias)
            channels.append(channel)
        }

        // Initiate default 
        let vc = MultiStreamViewController.instantiate()
        vc.phenixManager = phenixManager
        vc.channels = channels
        
        UIView.transition(with: self.navigationController.view) {
            self.navigationController.setViewControllers([vc], animated: false)
        }
    }
}

fileprivate extension UIView {
    class func transition(with view: UIView, duration: TimeInterval = 0.25, options: UIView.AnimationOptions = [.transitionCrossDissolve], animations: (() -> Void)?) {
        UIView.transition(with: view, duration: duration, options: options, animations: animations, completion: nil)
    }
}
