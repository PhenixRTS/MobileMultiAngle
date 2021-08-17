//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

extension PhenixConfiguration {
    public typealias UnrecoverableErrorHandler = (_ description: String?) -> Void

    public enum LogLevel: String {
        case all, trace, debug, info, warn, error, fatal, off
    }

    /// Uses provided configuration to make Room Express instance.
    /// - Parameter unrecoverableErrorCallback: Callback which gets triggered when the underlaying
    ///                                         PhenixSdk encounters an error which is not possible to resolve.
    /// - Returns: Phenix Room Express object, which must be hold with strong-reference.
    func makeRoomExpress(unrecoverableErrorCallback: @escaping UnrecoverableErrorHandler) -> PhenixRoomExpress {
        let pcastExpressOptions = PCastOptionsFactory.makePCastExpressOptions(
            configuration: self,
            unrecoverableErrorCallback: unrecoverableErrorCallback
        )
        let roomExpressOptions = RoomOptionsFactory.makeRoomExpressOptions(pcastExpressOptions: pcastExpressOptions)

        return PhenixRoomExpressFactory.createRoomExpress(roomExpressOptions)
    }

    /// Uses provided configuration to make Channel Express instance.
    /// - Parameter unrecoverableErrorCallback: Callback which gets triggered when the underlaying
    ///                                         PhenixSdk encounters an error which is not possible to resolve.
    /// - Returns: Phenix Channel Express object, which must be hold with strong-reference.
    func makeChannelExpress(unrecoverableErrorCallback: @escaping UnrecoverableErrorHandler) -> PhenixChannelExpress {
        let pcastExpressOptions = PCastOptionsFactory.makePCastExpressOptions(
            configuration: self,
            unrecoverableErrorCallback: unrecoverableErrorCallback
        )
        let roomExpressOptions = RoomOptionsFactory.makeRoomExpressOptions(pcastExpressOptions: pcastExpressOptions)
        let channelExpressOptions = ChannelOptionsFactory.makeChannelExpressOptions(
            roomExpressOptions: roomExpressOptions
        )

        return PhenixChannelExpressFactory.createChannelExpress(channelExpressOptions)
    }
}
