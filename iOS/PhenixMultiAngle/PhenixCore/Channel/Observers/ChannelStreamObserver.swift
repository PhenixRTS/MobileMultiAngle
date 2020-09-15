//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public protocol ChannelStreamObserver: AnyObject {
    func channelStreamStateDidChange(_ channel: Channel, state: Channel.StreamState)
}

// MARK: - Stream observation
public extension Channel {
    func addStreamObserver(_ observer: ChannelStreamObserver) {
        let id = ObjectIdentifier(observer)
        streamObservations[id] = StreamObservation(observer: observer)
    }

    func removeAudioObserver(_ observer: ChannelStreamObserver) {
        let id = ObjectIdentifier(observer)
        streamObservations.removeValue(forKey: id)
    }
}

internal extension Channel {
    struct StreamObservation {
        weak var observer: ChannelStreamObserver?
    }

    func channelStreamStateDidChange(state: Channel.StreamState) {
        for (id, observation) in streamObservations {
            // If the observer is no longer in memory, we can clean up the observation for its ID
            guard let observer = observation.observer else {
                streamObservations.removeValue(forKey: id)
                continue
            }

            observer.channelStreamStateDidChange(self, state: state)
        }
    }
}
