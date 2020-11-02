//
// Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

public final class PhenixManager {
    public typealias UnrecoverableErrorHandler = (_ description: String?) -> Void

    internal let privateQueue: DispatchQueue

    internal private(set) var channelExpress: PhenixChannelExpress!

    /// Backend URL used by Phenix SDK to communicate
    public let backend: URL
    public let pcast: URL?

    /// Initializer for Phenix manager
    /// - Parameters:
    ///   - backend: Backend URL for Phenix SDK
    ///   - pcast: PCast URL forn Phenix SDK
    public convenience init(backend: URL, pcast: URL?) {
        let privateQueue = DispatchQueue(label: "com.phenixrts.suite.multiangle.core.PhenixManager")
        self.init(backend: backend, pcast: pcast, privateQueue: privateQueue)
    }

    /// Initializer for internal tests
    /// - Parameters:
    ///   - backend: Backend URL for Phenix SDK
    ///   - pcast: PCast URL forn Phenix SDK
    ///   - privateQueue: Private queue used for making manager thread safe and possible to run on background threads
    internal init(backend: URL, pcast: URL?, privateQueue: DispatchQueue) {
        self.privateQueue = privateQueue
        self.backend = backend
        self.pcast = pcast
    }

    /// Creates necessary instances of PhenixSdk which provides connection and media streaming possibilities
    ///
    /// Method needs to be executed before trying to create or join rooms.
    public func start(unrecoverableErrorCompletion: @escaping UnrecoverableErrorHandler) {
        let group = DispatchGroup()

        group.enter()
        os_log(.debug, log: .phenixManager, "Room Express setup started")
        setupChannelExpress(backend: backend, unrecoverableErrorCompletion) {
            os_log(.debug, log: .phenixManager, "Room Express setup completed")
            group.leave()
        }

        group.wait()
    }
}

private extension PhenixManager {
    func setupChannelExpress(backend: URL, _ unrecoverableErrorCompletion: @escaping UnrecoverableErrorHandler, completion: @escaping () -> Void) {
        let pcastExpressOptions = PhenixOptionBuilder.createPCastExpressOptions(backend: backend, pcast: pcast, unrecoverableErrorCallback: unrecoverableErrorCompletion)
        let roomExpressOptions = PhenixOptionBuilder.createRoomExpressOptions(with: pcastExpressOptions)
        let channelExpressOptions = PhenixOptionBuilder.createChannelExpressOptions(with: roomExpressOptions)

        #warning("Remove async quick-fix when Channel Express will be thread safe.")
        DispatchQueue.main.async {
            self.channelExpress = PhenixChannelExpressFactory.createChannelExpress(channelExpressOptions)
            os_log(.debug, log: .phenixManager, "Channel Express initialized")

            completion()
        }
    }
}
