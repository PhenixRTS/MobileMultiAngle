//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

public class ChannelTimeShiftWorker {
    public enum TimeShiftAvailability {
        case notReady
        case ready
        case failure
    }

    private let channel: Channel
    private let timeShift: PhenixTimeShift
    private let duration: TimeInterval
    private let throttler: Throttler
    private let debouncer: Debouncer
    private let startDate: Date
    private let endDate: Date

    private var disposables = [PhenixDisposable]()
    private var bandwidthLimitationDisposable: PhenixDisposable?
    private var playbackHeadDisposable: PhenixDisposable?
    private var seekDisposable: PhenixDisposable?

    private(set) var state: TimeShiftAvailability = .notReady {
        didSet {
            os_log(.debug, log: .timeShift, "TimeShift state changed to %{PRIVATE}s, (%{PRIVATE}s)", String(describing: state), channel.description)
            channel.channelTimeShiftStateDidChange(state: state)
        }
    }

    init?(channel: Channel, initialDateTime: Date, configuration: TimeShiftReplayConfiguration) {
        guard let renderer = channel.renderer else {
            assertionFailure("Channel must have renderer initialized")
            return nil
        }

        guard renderer.isSeekable else {
            os_log(.debug, log: .timeShift, "Channel is not seekable, do not create TimeShift worker, (%{PRIVATE}s)", channel.description)
            return nil
        }

        let calendar = Calendar.current

        guard let modifiedStartTime = calendar.date(byAdding: configuration.playbackStartPoint, to: initialDateTime) else {
            assertionFailure("Incorrect modified start time, \(configuration.playbackStartPoint), \(initialDateTime)")
            return nil
        }

        // swiftlint:disable line_length
        os_log(.debug, log: .timeShift, "Create TimeShift worker with duration: %{PRIVATE}s, startPoint: %{PRIVATE}s, initial start time: %{PRIVATE}s modified start time: %{PRIVATE}s, (%{PRIVATE}s)", configuration.playbackDuration.description, configuration.playbackStartPoint.description, initialDateTime.description, modifiedStartTime.description, channel.description)

        self.channel = channel
        self.duration = configuration.playbackDuration
        self.timeShift = renderer.seek(modifiedStartTime)
        self.throttler = Throttler(delay: 0.5)
        self.debouncer = Debouncer(delay: 0.5)
        self.startDate = modifiedStartTime
        self.endDate = modifiedStartTime.addingTimeInterval(configuration.playbackDuration)
    }

    func subscribeForStatusEvents() {
        os_log(.debug, log: .timeShift, "Subscribe for TimeShift status changes, (%{PRIVATE}s)", channel.description)
        timeShift.getObservableReadyForPlaybackStatus()?.subscribe(timeShiftReadyForPlaybackStatusDidChange)?.append(to: &disposables)
        timeShift.getObservableFailure()?.subscribe(timeShiftFailureDidChange)?.append(to: &disposables)
    }

    func subscribeForPlaybackHeadEvents() {
        os_log(.debug, log: .timeShift, "Subscribe for TimeShift playback head changes, (%{PRIVATE}s)", channel.description)
        playbackHeadDisposable = timeShift.getObservablePlaybackHead()?.subscribe(timeShiftPlaybackHeadDidChange)
    }

    func unsubscribeForPlaybackHeadEvents() {
        playbackHeadDisposable = nil
        seekDisposable = nil
    }

    func startReplay() {
        os_log(.debug, log: .timeShift, "Start replay, (%{PRIVATE}s)", channel.description)
        timeShift.loop(duration)
    }

    func stopReplay() {
        os_log(.debug, log: .timeShift, "Stop replay, (%{PRIVATE}s)", channel.description)
        timeShift.stop()
    }

    func startBandwidthLimitation() {
        os_log(.debug, log: .timeShift, "Start limiting bandwidth, (%{PRIVATE}s)", channel.description)
        bandwidthLimitationDisposable = timeShift.limitBandwidth(PhenixConfiguration.channelBandwidthLimitation)
    }

    func stopBandwidthLimitation() {
        os_log(.debug, log: .timeShift, "Stop limiting bandwidth, (%{PRIVATE}s)", channel.description)
        bandwidthLimitationDisposable = nil
    }

    func movePlaybackHead(by time: TimeInterval) {
        // Pause and remove any of previous seek disposables
        timeShift.pause()
        seekDisposable = nil

        // Calculate the specific time to with we need to move the TimeShift
        let date = startDate.addingTimeInterval(time)

        // Validate calculated time
        assert(date >= startDate)
        assert(date <= endDate)

        debouncer.run { [weak self] in
            guard let self = self else {
                return
            }

            os_log(.debug, log: .timeShift, "Move playback head by %{PRIVATE}d, (%{PRIVATE}s)", time, self.channel.description)

            self.seekDisposable = self.timeShift.seek(date)?.subscribe(self.timeShiftSeekRelativeTimeDidChange)
        }
    }

    func dispose() {
        disposables.removeAll()
        bandwidthLimitationDisposable = nil
        playbackHeadDisposable = nil
        seekDisposable = nil
    }
}

private extension ChannelTimeShiftWorker {
    func timeShiftReadyForPlaybackStatusDidChange(_ changes: PhenixObservableChange<NSNumber>?) {
        guard let value = changes?.value else { return }
        let isAvailable = Bool(truncating: value)

        os_log(.debug, log: .timeShift, "TimeShift playback status changed: %{PRIVATE}s, (%{PRIVATE}s)", String(describing: isAvailable), channel.description)

        switch (isAvailable, state) {
        case (true, .notReady):
            state = .ready
        case (false, .ready):
            state = .notReady
        default:
            state = .failure
        }
    }

    func timeShiftPlaybackHeadDidChange(_ changes: PhenixObservableChange<NSDate>?) {
        throttler.run {
            guard let date = changes?.value as Date? else {
                return
            }

            os_log(.debug, log: .timeShift, "TimeShift playback head callback with date: %{PRIVATE}s , (%{PRIVATE}s)", date.description, self.channel.description)
            self.channel.channelTimeShiftPlaybackHeadDidChange(startDate: self.startDate, currentDate: date, endDate: self.endDate)
        }
    }

    func timeShiftFailureDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
        guard let value = changes?.value else { return }

        os_log(.debug, log: .timeShift, "TimeShift failure callback, status: %{PRIVATE}d, (%{PRIVATE}s)", value.status.rawValue, channel.description)

        if value.status != .ok {
            state = .failure
        }
    }

    func timeShiftSeekRelativeTimeDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
        guard let value = changes?.value else { return }

        os_log(.debug, log: .timeShift, "TimeShift seek relative time callback, status: %{PRIVATE}d, (%{PRIVATE}s)", value.status.rawValue, channel.description)

        switch value.status {
        case .ok:
            timeShift.play()
        default:
            state = .failure
        }
    }
}
