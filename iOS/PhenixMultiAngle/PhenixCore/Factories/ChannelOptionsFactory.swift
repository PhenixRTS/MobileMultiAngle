//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

enum ChannelOptionsFactory {
    static func makeJoinChannelOptions(
        configuration: PhenixConfiguration,
        joinRoomOptions: PhenixJoinRoomOptions,
        rendererLayer: CALayer,
        rendererOptions: PhenixRendererOptions
    ) -> PhenixJoinChannelOptions {
        let channelOptionsBuilder: PhenixJoinChannelOptionsBuilder = PhenixChannelExpressFactory
            .createJoinChannelOptionsBuilder()

        if let token = configuration.edgeToken {
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
