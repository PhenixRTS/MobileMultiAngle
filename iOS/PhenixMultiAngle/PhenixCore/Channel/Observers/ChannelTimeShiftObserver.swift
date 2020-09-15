//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public protocol ChannelTimeShiftObserver: AnyObject {
    func channelTimeShiftStateDidChange(_ channel: Channel, state: ChannelTimeShiftWorker.TimeShiftAvailability)
    func channelTimeShiftDidChangePlaybackHead(_ channel: Channel, startDate: Date, currentDate: Date, endDate: Date)
}

// MARK: - Stream observation
public extension Channel {
    func addTimeShiftObserver(_ observer: ChannelTimeShiftObserver) {
        let id = ObjectIdentifier(observer)
        timeShiftObservations[id] = TimeShiftObservation(observer: observer)
    }

    func removeAudioObserver(_ observer: ChannelTimeShiftObserver) {
        let id = ObjectIdentifier(observer)
        timeShiftObservations.removeValue(forKey: id)
    }
}

internal extension Channel {
    struct TimeShiftObservation {
        weak var observer: ChannelTimeShiftObserver?
    }

    func channelTimeShiftStateDidChange(state: ChannelTimeShiftWorker.TimeShiftAvailability) {
        forEach { observer in
            observer.channelTimeShiftStateDidChange(self, state: state)
        }
    }

    func channelTimeShiftPlaybackHeadDidChange(startDate: Date, currentDate: Date, endDate: Date) {
        forEach { observer in
            observer.channelTimeShiftDidChangePlaybackHead(self, startDate: startDate, currentDate: currentDate, endDate: endDate)
        }
    }
}

fileprivate extension Channel {
    func forEach(then: (ChannelTimeShiftObserver) -> Void) {
        for (id, observation) in timeShiftObservations {
            // If the observer is no longer in memory, we can clean up the observation for its ID
            guard let observer = observation.observer else {
                timeShiftObservations.removeValue(forKey: id)
                continue
            }

            then(observer)
        }
    }
}
