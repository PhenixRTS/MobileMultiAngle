//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

enum RoomOptionsFactory {
    static func makeRoomOptions(alias: String) -> PhenixRoomOptions {
        PhenixRoomServiceFactory.createRoomOptionsBuilder()
            .withName(alias)
            .withAlias(alias)
            .withType(.multiPartyChat)
            .buildRoomOptions()
    }

    static func makeJoinRoomOptions(
        configuration: PhenixConfiguration,
        alias: String,
        screenName: String? = nil
    ) -> PhenixJoinRoomOptions {
        let joinRoomOptionBuilder: PhenixJoinRoomOptionsBuilder = PhenixRoomExpressFactory
            .createJoinRoomOptionsBuilder()

        if configuration.edgeToken == nil {
            joinRoomOptionBuilder.withCapabilities(configuration.capabilities)
        }

        return joinRoomOptionBuilder
            .withRoomAlias(alias)
            .withScreenName(screenName)
            .buildJoinRoomOptions()
    }

    static func makePublishToRoomOptions(
        roomID: String,
        publishOptions: PhenixPublishOptions,
        screenName: String? = nil
    ) -> PhenixPublishToRoomOptions {
        PhenixRoomExpressFactory.createPublishToRoomOptionsBuilder()
            .withRoomId(roomID)
            .withPublishOptions(publishOptions)
            .withScreenName(screenName)
            .buildPublishToRoomOptions()
    }

    static func makeRoomExpressOptions(pcastExpressOptions: PhenixPCastExpressOptions) -> PhenixRoomExpressOptions {
        PhenixRoomExpressFactory
            .createRoomExpressOptionsBuilder()
            .withPCastExpressOptions(pcastExpressOptions)
            .buildRoomExpressOptions()
    }
}
