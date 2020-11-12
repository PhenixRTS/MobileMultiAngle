//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

protocol TimeShiftDelegate: AnyObject {
    func timeShiftDidFail()
    func timeShiftDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date)
    func timeShiftDidChangeState(_ state: ChannelTimeShiftWorker.TimeShiftState)
}

public class ChannelTimeShiftWorker {
    private let renderer: PhenixRenderer
    private let duration: TimeInterval
    private let throttler: Throttler
    private let debouncer: Debouncer
    private let startDate: Date
    private let endDate: Date

    private var timeShift: PhenixTimeShift
    private var disposables = [PhenixDisposable]()
    private var bandwidthLimitationDisposable: PhenixDisposable?
    private var playbackHeadDisposable: PhenixDisposable?
    private var seekDisposable: PhenixDisposable?

    private(set) var state: TimeShiftState = .starting {
        didSet {
            if oldValue != state {
                os_log(.debug, log: .timeShift, "TimeShift state did change to %{PRIVATE}s", String(describing: state), channelDescription)
                delegate?.timeShiftDidChangeState(state)
            }
        }
    }

    internal weak var channelRepresentation: ChannelRepresentation?
    internal weak var delegate: TimeShiftDelegate?

    init(renderer: PhenixRenderer, initialDateTime: Date, configuration: ReplayConfiguration, calendar: Calendar = .current) throws {
        guard renderer.isSeekable else {
            os_log(.debug, log: .timeShift, "Renderer is not seek-able, do not create TimeShift worker")
            throw TimeShiftError.rendererNotSeekable
        }

        guard let modifiedStartTime = calendar.date(byAdding: configuration.playbackStartPoint, to: initialDateTime) else {
            fatalError("Fatal error, Incorrect modified start time, \(configuration.playbackStartPoint), \(initialDateTime)")
        }

        // swiftlint:disable line_length
        os_log(.debug, log: .timeShift, "Create TimeShift worker with duration: %{PRIVATE}s, startPoint: %{PRIVATE}s, initial start time: %{PRIVATE}s modified start time: %{PRIVATE}s", configuration.playbackDuration.description, configuration.playbackStartPoint.description, initialDateTime.description, modifiedStartTime.description)

        self.renderer = renderer
        self.duration = configuration.playbackDuration
        self.throttler = Throttler(delay: 0.5)
        self.debouncer = Debouncer(delay: 0.5)
        self.startDate = modifiedStartTime
        self.endDate = modifiedStartTime.addingTimeInterval(configuration.playbackDuration)

        self.timeShift = renderer.seek(modifiedStartTime)
    }

    func subscribeForStatusEvents() {
        os_log(.debug, log: .timeShift, "Subscribe for TimeShift status events, (%{PRIVATE}s)", channelDescription)
        timeShift.getObservableReadyForPlaybackStatus()?.subscribe(timeShiftReadyForPlaybackStatusDidChange)?.append(to: &disposables)
        timeShift.getObservableFailure()?.subscribe(timeShiftFailureDidChange)?.append(to: &disposables)
    }

    func subscribeForPlaybackHeadEvents() {
        os_log(.debug, log: .timeShift, "Subscribe for TimeShift playback head change events, (%{PRIVATE}s)", channelDescription)
        playbackHeadDisposable = timeShift.getObservablePlaybackHead()?.subscribe(timeShiftPlaybackHeadDidChange)
    }

    func unsubscribeForPlaybackHeadEvents() {
        playbackHeadDisposable = nil
        seekDisposable = nil
    }

    func startReplay() {
        os_log(.debug, log: .timeShift, "Start replay, (%{PRIVATE}s)", channelDescription)
        state = .playing
        timeShift.loop(duration)
    }

    func stopReplay() {
        os_log(.debug, log: .timeShift, "Stop replay, (%{PRIVATE}s)", channelDescription)
        state = .readyToPlay
        timeShift.stop()
    }

    func limitBandwidth(at bandwidth: PhenixBandwidthLimit) {
        os_log(.debug, log: .timeShift, "Start limiting bandwidth at %{PUBLIC}d, (%{PRIVATE}s)", bandwidth.rawValue, channelDescription)
        bandwidthLimitationDisposable = timeShift.limitBandwidth(bandwidth.rawValue)
    }

    func stopBandwidthLimitation() {
        os_log(.debug, log: .timeShift, "Stop limiting bandwidth, (%{PRIVATE}s)", channelDescription)
        bandwidthLimitationDisposable = nil
    }

    func movePlaybackHead(by time: TimeInterval) {
        // Pause and remove any of previous seek disposables
        timeShift.pause()
        seekDisposable = nil

        debouncer.run { [weak self] in
            guard let self = self else {
                return
            }

            os_log(.debug, log: .timeShift, "Move playback head to %{PRIVATE}s in timeline, (%{PRIVATE}s)", time.description, self.channelDescription)
            self.state = .loadingPlayback
            self.seekDisposable = self.timeShift.seek(time, .beginning)?.subscribe(self.timeShiftSeekRelativeTimeDidChange)
        }
    }

    func dispose() {
        disposables.removeAll()
        bandwidthLimitationDisposable = nil
        playbackHeadDisposable = nil
        seekDisposable = nil
    }
}

public extension ChannelTimeShiftWorker {
    enum TimeShiftError: Error {
        case rendererNotSeekable
    }

    enum TimeShiftState {
        case starting
        case readyToPlay
        case loadingPlayback
        case playing
        case failure
    }
}

private extension ChannelTimeShiftWorker {
    var channelDescription: String { channelRepresentation?.alias ?? "-" }

    func timeShiftReadyForPlaybackStatusDidChange(_ changes: PhenixObservableChange<NSNumber>?) {
        guard let value = changes?.value else { return }
        let isAvailable = Bool(truncating: value)

        switch (isAvailable, state) {
        case (true, .starting):
            state = .readyToPlay

        case (true, .playing),
             (_, .loadingPlayback):
            state = .playing

        case (false, .readyToPlay):
            state = .starting

        default:
            state = .starting
        }

        os_log(.debug, log: .timeShift, "TimeShift playback status changed, isAvailable: %{PRIVATE}s, new state: %{PRIVATE}s, (%{PRIVATE}s)", String(describing: isAvailable), String(describing: state), channelDescription)
    }

    func timeShiftPlaybackHeadDidChange(_ changes: PhenixObservableChange<NSDate>?) {
        throttler.run {
            guard let date = changes?.value as Date? else {
                return
            }

            os_log(.debug, log: .timeShift, "TimeShift playback head callback with date: %{PRIVATE}s, (%{PRIVATE}s)", date.description, channelDescription)

            state = .playing
            delegate?.timeShiftDidChangePlaybackHead(startDate: startDate, currentDate: date, endDate: endDate)
        }
    }

    func timeShiftFailureDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
        guard let value = changes?.value else {
            return
        }

        os_log(.debug, log: .timeShift, "TimeShift failure callback, status: %{PRIVATE}d, (%{PRIVATE}s)", value.status.rawValue, channelDescription)

        guard value.status != .ok else {
            return
        }

        delegate?.timeShiftDidFail()
    }

    func timeShiftSeekRelativeTimeDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
        guard let value = changes?.value else {
            return
        }

        os_log(.debug, log: .timeShift, "TimeShift seek relative time callback, status: %{PRIVATE}d, (%{PRIVATE}s)", value.status.rawValue, channelDescription)

        switch value.status {
        case .ok:
            timeShift.play()
        default:
            delegate?.timeShiftDidFail()
        }
    }
}
