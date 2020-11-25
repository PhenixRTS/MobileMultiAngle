//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

internal protocol TimeShiftDelegate: AnyObject {
    func timeShiftDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date)
    func timeShiftDidChangeState(_ state: TimeShiftWorker.State)
}

internal class TimeShiftWorker {
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

    private(set) var state: State = .starting {
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

        self.state = .starting
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
        os_log(.debug, log: .timeShift, "Unsubscribe for TimeShift playback head change events, (%{PRIVATE}s)", channelDescription)
        playbackHeadDisposable = nil
        seekDisposable = nil
    }

    func startReplay() {
        guard state == .readyToPlay else {
            os_log(.debug, log: .timeShift, "TimeShift is not ready, can't start - %{PRIVATE}s, (%{PRIVATE}s)", String(describing: state), channelDescription)
            return
        }
        os_log(.debug, log: .timeShift, "Start replay, (%{PRIVATE}s)", channelDescription)
        state = .playing
        timeShift.loop(duration)
    }

    func stopReplay(forceFailure: Bool = false) {
        if case .failure = state {
            os_log(.debug, log: .timeShift, "TimeShift is not playing, can't stop - %{PRIVATE}s, (%{PRIVATE}s)", String(describing: state), channelDescription)
            return
        }

        if state == .ended {
            os_log(.debug, log: .timeShift, "TimeShift is not playing, can't stop - %{PRIVATE}s, (%{PRIVATE}s)", String(describing: state), channelDescription)
            return
        }

        os_log(.debug, log: .timeShift, "Stop replay, (%{PRIVATE}s)", channelDescription)
        state = forceFailure == true ? .failure(forced: true) : .readyToPlay
        timeShift.stop()
        debouncer.invalidate()
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
        self.state = .seeking

        timeShift.pause()
        seekDisposable = nil

        debouncer.run { [weak self] in
            guard let self = self else { return }

            os_log(.debug, log: .timeShift, "Seek offset %{PRIVATE}s, (%{PRIVATE}s)", time.description, self.channelDescription)
            self.seekDisposable = self.timeShift.seek(time, .beginning)?.subscribe(self.timeShiftSeekRelativeTimeDidChange)
        }
    }

    func dispose() {
        os_log(.debug, log: .timeShift, "Dispose, (%{PRIVATE}s)", channelDescription)
        disposables.removeAll()
        bandwidthLimitationDisposable = nil
        playbackHeadDisposable = nil
        seekDisposable = nil
        debouncer.invalidate()
    }
}

internal extension TimeShiftWorker {
    enum TimeShiftError: Error {
        case rendererNotSeekable
    }

    enum State: Equatable {
        case starting
        case seeking
        case readyToPlay
        case playing
        case ended
        case failure(forced: Bool)
    }
}

private extension TimeShiftWorker {
    var channelDescription: String { channelRepresentation?.alias ?? "-" }

    func timeShiftReadyForPlaybackStatusDidChange(_ changes: PhenixObservableChange<NSNumber>?) {
        guard let value = changes?.value else { return }
        let isAvailable = Bool(truncating: value)

        if case let .failure(forced) = state, forced == true {
            // Case when TimeShift has failed can mean that it failed to load the stream or it was "forced to stop" with failure state.
            // We do not want to update the state when the failure was forced.
            os_log(.debug, log: .timeShift, "TimeShift was forced to fail, to need for state change, (%{PRIVATE}s)", channelDescription)
            return
        }

        guard state != .seeking else {
            // Case when TimeShift is seeking another timestamp from which to start playing.
            // In this case we need to rely on the Seek Relative Time callback.
            os_log(.debug, log: .timeShift, "TimeShift is currently seeking, no need for state change, (%{PRIVATE}s)", channelDescription)
            return
        }

        if isAvailable == true && state == .playing {
            // If the TimeShift is already playing and the `isAvailable` is `true`, we do not need to change the state.
            os_log(.debug, log: .timeShift, "TimeShift is already playing, no need for state change, (%{PRIVATE}s)", channelDescription)
            return
        }

        if isAvailable {
            state = .readyToPlay
        } else {
            state = .starting
        }

        os_log(.debug, log: .timeShift, "Playback status changed. Available: %{PRIVATE}s, state: %{PRIVATE}s, (%{PRIVATE}s)", isAvailable.description, String(describing: state), channelDescription)
    }

    func timeShiftPlaybackHeadDidChange(_ changes: PhenixObservableChange<NSDate>?) {
        throttler.run {
            guard let date = changes?.value as Date? else {
                return
            }

            os_log(.debug, log: .timeShift, "TimeShift playback head callback with date: %{PRIVATE}s, (%{PRIVATE}s)", date.description, channelDescription)

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

        state = .failure(forced: false)
    }

    func timeShiftSeekRelativeTimeDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
        guard let value = changes?.value else {
            return
        }

        os_log(.debug, log: .timeShift, "TimeShift seek relative time callback, status: %{PRIVATE}d, (%{PRIVATE}s)", value.status.rawValue, channelDescription)

        switch value.status {
        case .ok:
            state = .playing
            timeShift.play()

        default:
            state = .failure(forced: false)
        }
    }
}
