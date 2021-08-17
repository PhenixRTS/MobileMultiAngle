//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

enum StreamOptionsFactory {
    static func makeSubscribeToMemberAudioStreamOptions() -> PhenixSubscribeToMemberStreamOptions {
        PhenixRoomExpressFactory.createSubscribeToMemberStreamOptionsBuilder()
            .withCapabilities(["audio-only"])
            .buildSubscribeToMemberStreamOptions()
    }

    static func makeSubscribeToMemberVideoStreamOptions() -> PhenixSubscribeToMemberStreamOptions {
        PhenixRoomExpressFactory.createSubscribeToMemberStreamOptionsBuilder()
            .withCapabilities(["video-only"])
            .buildSubscribeToMemberStreamOptions()
    }
}
