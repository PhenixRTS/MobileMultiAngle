//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

enum PhenixOptionBuilder {
    static func createPCastExpressOptions(backend: URL, unrecoverableErrorCallback: @escaping (_ description: String?) -> Void) -> PhenixPCastExpressOptions {
        PhenixPCastExpressFactory.createPCastExpressOptionsBuilder()
            .withBackendUri(backend.absoluteString)
            .withUnrecoverableErrorCallback { _, description in
                os_log(.error, log: .phenixManager, "Unrecoverable Error: %{PRIVATE}s", String(describing: description))
                unrecoverableErrorCallback(description)
            }
            .buildPCastExpressOptions()
    }

    static func createRoomExpressOptions(with pcastExpressOptions: PhenixPCastExpressOptions) -> PhenixRoomExpressOptions {
        PhenixRoomExpressFactory.createRoomExpressOptionsBuilder()
            .withPCastExpressOptions(pcastExpressOptions)
            .buildRoomExpressOptions()
    }

    static func createChannelExpressOptions(with roomExpressOptions: PhenixRoomExpressOptions) -> PhenixChannelExpressOptions {
        PhenixChannelExpressFactory.createChannelExpressOptionsBuilder()
            .withRoomExpressOptions(roomExpressOptions)
            .buildChannelExpressOptions()
    }

    static func createMemberStreamOptions() -> PhenixSubscribeToMemberStreamOptions {
        PhenixRoomExpressFactory
            .createSubscribeToMemberStreamOptionsBuilder()
            .buildSubscribeToMemberStreamOptions()
    }

    static func createJoinRoomOptions(withAlias alias: String) -> PhenixJoinRoomOptions {
        PhenixRoomExpressFactory.createJoinRoomOptionsBuilder()
            .withRoomAlias(alias)
            .buildJoinRoomOptions()
    }

    static func createJoinChannelOptions(with joinRoomOptions: PhenixJoinRoomOptions, rendererLayer: CALayer, rendererOptions: PhenixRendererOptions) -> PhenixJoinChannelOptions {
        PhenixChannelExpressFactory.createJoinChannelOptionsBuilder()
            .withJoinRoomOptions(joinRoomOptions)
            .withStreamSelectionStrategy(.highAvailability)
            .withRenderer(rendererLayer)
            .withRendererOptions(rendererOptions)
            .buildJoinChannelOptions()
    }
}
