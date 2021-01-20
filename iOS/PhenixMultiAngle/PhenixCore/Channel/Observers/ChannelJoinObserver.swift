//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public protocol ChannelJoinObserver: AnyObject {
    func channel(_ channel: Channel, didChange state: Channel.JoinState)
}

// MARK: - Connection observation
public extension Channel {
    func addJoinObserver(_ observer: ChannelJoinObserver) {
        let id = ObjectIdentifier(observer)
        joinObservations[id] = JoinObservation(observer: observer)
    }

    func removeAudioObserver(_ observer: ChannelJoinObserver) {
        let id = ObjectIdentifier(observer)
        joinObservations.removeValue(forKey: id)
    }
}

internal extension Channel {
    struct JoinObservation {
        weak var observer: ChannelJoinObserver?
    }

    func channelJoinStateDidChange(state: Channel.JoinState) {
        for (id, observation) in joinObservations {
            // If the observer is no longer in memory, we can clean up the observation for its ID
            guard let observer = observation.observer else {
                joinObservations.removeValue(forKey: id)
                continue
            }

            observer.channel(self, didChange: state)
        }
    }
}
