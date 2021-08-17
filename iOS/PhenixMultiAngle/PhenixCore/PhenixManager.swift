//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

public final class PhenixManager {
    public typealias UnrecoverableErrorHandler = PhenixConfiguration.UnrecoverableErrorHandler

    internal let queue: DispatchQueue
    internal private(set) var channelExpress: PhenixChannelExpress?

    public let configuration: PhenixConfiguration

    /// Initializer for Phenix manager
    /// - Parameters:
    ///   - backend: Backend URL for Phenix SDK
    ///   - pcast: PCast URL forn Phenix SDK
    public init(configuration: PhenixConfiguration = .default) {
        self.queue = DispatchQueue(label: "com.phenixrts.suite.multiangle.core.PhenixManager", qos: .userInitiated)
        self.configuration = configuration
    }

    /// Creates necessary instances of PhenixSdk which provides connection and media streaming possibilities
    ///
    /// Method needs to be executed before trying to create or join rooms.
    public func start(unrecoverableErrorCompletion: @escaping UnrecoverableErrorHandler) {
        os_log(.debug, log: .phenixManager, "Setup Channel Express")

        queue.sync {
            self.channelExpress = configuration.makeChannelExpress(unrecoverableErrorCallback: unrecoverableErrorCompletion)
        }
    }
}
