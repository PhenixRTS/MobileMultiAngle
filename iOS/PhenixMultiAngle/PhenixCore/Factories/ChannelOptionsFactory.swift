//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

enum ChannelOptionsFactory {
    static func makeJoinChannelOptions(
        streamToken: String?,
        joinRoomOptions: PhenixJoinRoomOptions,
        rendererLayer: CALayer,
        rendererOptions: PhenixRendererOptions
    ) -> PhenixJoinChannelOptions {
        let channelOptionsBuilder: PhenixJoinChannelOptionsBuilder = PhenixChannelExpressFactory
            .createJoinChannelOptionsBuilder()

        if let token = streamToken {
            channelOptionsBuilder
                .withStreamToken(token)
                .withSkipRetryOnUnauthorized()
        }

        return channelOptionsBuilder
            .withJoinRoomOptions(joinRoomOptions)
            .withStreamSelectionStrategy(.highAvailability)
            .withRenderer(rendererLayer)
            .withRendererOptions(rendererOptions)
            .buildJoinChannelOptions()
    }

    static func makeChannelExpressOptions(roomExpressOptions: PhenixRoomExpressOptions) -> PhenixChannelExpressOptions {
        PhenixChannelExpressFactory
            .createChannelExpressOptionsBuilder()
            .withRoomExpressOptions(roomExpressOptions)
            .buildChannelExpressOptions()
    }
}
