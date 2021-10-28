//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixCore
import UIKit

class MainCoordinator: Coordinator {
    let navigationController: UINavigationController
    private let dependencyContainer: DependencyContainer
    private(set) var childCoordinators = [Coordinator]()
    private(set) var channelAliases: [String]
    private(set) var streamTokens: [String]

    private var phenixManager: PhenixManager { dependencyContainer.phenixManager }
    var configuration: PhenixConfiguration { phenixManager.configuration }

    init(
        navigationController: UINavigationController,
        dependencyContainer: DependencyContainer,
        channelAliases: [String],
        streamTokens: [String]
    ) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
        self.channelAliases = channelAliases
        self.streamTokens = streamTokens
    }

    func start() {
        os_log(.debug, log: .coordinator, "Main coordinator started")

        guard channelAliases.count == streamTokens.count else {
            AppDelegate.terminate(
                afterDisplayingAlertWithTitle: "Missing channel information",
                message: "Channel alias and stream token count must match."
            )
            return
        }

        var channels: [Channel] = []

        // Initiate default
        let vc = MultiStreamViewController.instantiate()

        // Convert aliases into channel models
        for (index, alias) in channelAliases.enumerated() {
            let streamToken: String? = streamTokens[index]
            let ccEnabled = index == 0 ? true : false
            // Enable closed captions only for the first channel in the list
            let channel = Channel(alias: alias, token: streamToken, closedCaptionsEnabled: ccEnabled)

            if ccEnabled {
                vc.ccChannel = channel
            }

            channel.closedCaptionsServiceDelegate = vc
            channels.append(channel)
        }

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
