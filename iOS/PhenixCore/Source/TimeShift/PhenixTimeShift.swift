//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Combine
import Foundation
import os.log
import PhenixSdk

extension PhenixCore {
    public class TimeShift {
        private static let logger = OSLog(identifier: "TimeShift")
        static let retryDelayTimeInterval: TimeInterval = 10

        private let queue: DispatchQueue
        private let renderer: PhenixRenderer
        private let initialPointInTime: PointInTime
        private let maxRetryCount: Int

        private var timeShift: PhenixTimeShift?
        private var retriesLeft: Int

        private var noStreamCancellable: AnyCancellable?

        private var delayedTimeShiftSetupWorker: DispatchWorkItem?

        private var playbackHeadEventDisposable: PhenixDisposable?
        private var playbackEndedEventDisposable: PhenixDisposable?
        private var playbackStatusEventDisposable: PhenixDisposable?
        private var playbackFailureEventDisposable: PhenixDisposable?
        private var seekRelativeTimeEventDisposable: PhenixDisposable?

        private var bandwidthLimitationDisposable: PhenixDisposable?

        // MARK: - Subjects
        private var eventSubject = PassthroughSubject<TimeShift.Event, Never>()
        private var playbackStateSubject = CurrentValueSubject<State, Never>(.idle)
        private var playbackHeadSubject = CurrentValueSubject<TimeInterval, Never>(0)

        // MARK: - Publishers
        lazy var eventPublisher: AnyPublisher<TimeShift.Event, Never> = eventSubject.eraseToAnyPublisher()

        lazy var playbackStatePublisher: AnyPublisher<State, Never> = playbackStateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()

        lazy var playbackHeadPublisher: AnyPublisher<TimeInterval, Never> = playbackHeadSubject
            .throttle(for: .milliseconds(500), scheduler: queue, latest: true)
            .removeDuplicates()
            .eraseToAnyPublisher()

        /// A variable informing about situations when the stream ends.
        var noStreamSubject = PassthroughSubject<(), Never>()

        let alias: String
        var state: State { playbackStateSubject.value }

        init(
            renderer: PhenixRenderer,
            pointInTime: PointInTime,
            maxRetryCount: Int,
            associatedAlias: String,
            queue: DispatchQueue
        ) {
            self.queue = queue
            self.alias = associatedAlias
            self.renderer = renderer
            self.retriesLeft = maxRetryCount
            self.maxRetryCount = maxRetryCount
            self.initialPointInTime = pointInTime

            self.noStreamCancellable = self.noStreamSubject
                .sink { [weak self] _ in
                    // Prevent of any more retries, because the stream ended.
                    self?.preventFromRetrying()
                }
        }

        func setup() {
            guard renderer.isSeekable else {
                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, Renderer is not seekable, failed to create TimeShift context.",
                    alias
                )
                eventSubject.send(.timeShiftFailed(alias: alias, error: .rendererNotSeekable))
                playbackStateSubject.send(.failed)
                return
            }

            setupTimeShift()
            retriesLeft = maxRetryCount

            if timeShift == nil {
                eventSubject.send(.timeShiftFailed(alias: alias, error: .rendererSeekingFailed))
                playbackStateSubject.send(.failed)
            }
        }

        func subscribeForPlaybackStatusEvents() {
            guard let timeShift = timeShift else {
                return
            }

            os_log(.debug, log: Self.logger, "%{private}s, Subscribe for playback status events", alias)
            playbackStateSubject.send(.starting)

            playbackStatusEventDisposable = timeShift
                .getObservableReadyForPlaybackStatus()
                .subscribe { [weak self] changes in
                    self?.playbackStatusDidChange(changes)
                }

            playbackFailureEventDisposable = timeShift
                .getObservableFailure()
                .subscribe { [weak self] changes in
                    self?.playbackFailureDidChange(changes)
                }

            playbackEndedEventDisposable = timeShift
                .getObservableEnded()
                .subscribe { [weak self] changes in
                    self?.playbackEndedDidChange(changes)
                }
        }

        func subscribeForPlaybackHeadEvents() {
            guard let timeShift = timeShift else {
                return
            }

            os_log(.debug, log: Self.logger, "%{private}s, Subscribe for playback head events", alias)

            playbackHeadEventDisposable = timeShift
                .getObservablePlaybackHead()
                .subscribe { [weak self] changes in
                    self?.playbackHeadDidChange(changes)
                }
        }

        func unsubscribeFromPlaybackHeadEvents() {
            playbackHeadEventDisposable = nil
            seekRelativeTimeEventDisposable = nil
        }

        func pause() {
            guard let timeShift = timeShift else {
                return
            }

            guard isReadyToPause else {
                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, State (%{private}s) prevents pausing.",
                    alias,
                    state.description
                )

                eventSubject.send(.timeShiftFailed(alias: alias, error: .pausingFailed))
                return
            }

            os_log(.debug, log: Self.logger, "%{private}s, Pause.", alias)

            timeShift.pause()
            playbackStateSubject.send(.paused)
        }

        func play() {
            guard let timeShift = timeShift else {
                return
            }

            guard isReadyToPlay else {
                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, State (%{private}s) prevents playing.",
                    alias,
                    state.description
                )

                eventSubject.send(.timeShiftFailed(alias: alias, error: .playingFailed))
                return
            }

            os_log(.debug, log: Self.logger, "%{private}s, Play.", alias)

            timeShift.play()
            playbackStateSubject.send(.playing)
        }

        func play(loop duration: TimeInterval) {
            guard let timeShift = timeShift else {
                return
            }

            guard isReadyToPlay else {
                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, State (%{private}s) prevents playing loop.",
                    alias,
                    state.description
                )

                eventSubject.send(.timeShiftFailed(alias: alias, error: .playingFailed))
                return
            }

            os_log(
                .debug,
                log: Self.logger,
                "%{private}s, Play loop of %{private}s.",
                alias,
                String(describing: duration)
            )

            timeShift.loop(duration)
            playbackStateSubject.send(.playing)
        }

        func stop() {
            guard let timeShift = timeShift else {
                return
            }

            guard isReadyToStop else {
                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, State (%{private}s) prevents stoping",
                    alias,
                    state.description
                )

                eventSubject.send(.timeShiftFailed(alias: alias, error: .stopingFailed))
                return
            }

            os_log(.debug, log: Self.logger, "%{private}s, Stop", alias)

            timeShift.stop()
            playbackStateSubject.send(.ready)
        }

        func seek(offset: TimeInterval) {
            guard let timeShift = timeShift else {
                return
            }

            guard isReadyToSeek else {
                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, State (%{private}s) prevents seeking",
                    alias,
                    state.description
                )

                eventSubject.send(.timeShiftFailed(alias: alias, error: .seekingFailed))
                return
            }

            os_log(
                .debug,
                log: Self.logger,
                "%{private}s, Seek offset %{private}s",
                alias,
                String(describing: offset)
            )

            timeShift.pause()
            playbackStateSubject.send(.seeking)
            seekRelativeTimeEventDisposable = timeShift.seek(offset, .beginning)
                .subscribe { [weak self] changes in
                    self?.seekRelativeTimeDidChange(changes)
                }
        }

        func setBandwidthLimitation(_ bandwidth: UInt64) {
            bandwidthLimitationDisposable = nil

            guard let timeShift = timeShift else {
                return
            }

            os_log(.debug, log: Self.logger, "%{private}s, Set bandwidth limitation: %{private}d", alias, bandwidth)
            bandwidthLimitationDisposable = timeShift.limitBandwidth(bandwidth)
        }

        func removeBandwidthLimitation() {
            os_log(.debug, log: Self.logger, "%{private}s, Remove bandwidth limitation", alias)
            bandwidthLimitationDisposable = nil
        }

        // MARK: - Private methods

        private func setupTimeShift() {
            os_log(
                .debug,
                log: Self.logger,
                "%{private}s, Setup TimeShift at %{private}s.",
                alias,
                initialPointInTime.description
            )

            switch initialPointInTime {
            case .seek(let offset, let from):
                timeShift = renderer.seek(offset, from.phenixSeekOrigin)

            case .timestamp(let date):
                timeShift = renderer.seek(date)
            }

            guard timeShift != nil else {
                os_log(.debug, log: Self.logger, "%{private}s, Failed to setup TimeShift", alias)
                return
            }

            os_log(
                .debug,
                log: Self.logger,
                "%{private}s, Setup TimeShift succeeded, max retry count %{private}s",
                alias,
                maxRetryCount.description
            )

            subscribeForPlaybackStatusEvents()
            subscribeForPlaybackHeadEvents()
        }

        /// A method preveting from further TimeShift setups by removing all available retries.
        ///
        /// This method should be used, for example, when the remote stream is no longer available.
        /// In that case, there is no need of multe retries to setup TimeShift.
        private func preventFromRetrying() {
            os_log(.debug, log: Self.logger, "%{private}s, Prevent further retries", alias)
            retriesLeft = 0
            delayedTimeShiftSetupWorker?.cancel()
            delayedTimeShiftSetupWorker = nil
        }

        private func playbackStatusDidChange(_ changes: PhenixObservableChange<NSNumber>?) {
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }

                guard let value = changes?.value else {
                    return
                }

                let isAvailable = Bool(truncating: value)

                guard self.state != .playing && self.state != .seeking else {
                    return
                }

                let state: State = isAvailable ? .ready : .starting

                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, Playback status changed to %{private}s",
                    self.alias,
                    state.description
                )

                self.playbackStateSubject.send(state)
            }
        }

        private func playbackHeadDidChange(_ changes: PhenixObservableChange<NSDate>?) {
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }

                guard let timeShift = self.timeShift else {
                    return
                }

                guard let date = changes?.value as Date? else {
                    return
                }

                let duration = DateInterval(start: timeShift.startTime, end: date).duration

                self.playbackHeadSubject.send(duration)
            }
        }

        private func playbackFailureDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }

                guard let value = changes?.value else {
                    return
                }

                guard value.status != .ok else {
                    return
                }

                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, Playback failed: %{private}s.",
                    self.alias,
                    value.status.description
                )

                os_log(
                    .debug,
                    log: Self.logger,
                    "%{private}s, %{private}s/%{private}s retries left for new TimeShift setup",
                    self.alias,
                    self.retriesLeft.description,
                    self.maxRetryCount.description
                )

                if self.retriesLeft > 0 {
                    os_log(
                        .debug,
                        log: Self.logger,
                        "%{private}s, Retry TimeShift setup after %{private}s seconds",
                        self.alias,
                        Self.retryDelayTimeInterval.description
                    )

                    self.retriesLeft -= 1
                    self.playbackStateSubject.send(.starting)

                    let workItem = DispatchWorkItem { [weak self] in
                        self?.setupTimeShift()
                    }

                    self.delayedTimeShiftSetupWorker = workItem
                    self.queue.asyncAfter(deadline: .now() + Self.retryDelayTimeInterval, execute: workItem)
                } else {
                    self.delayedTimeShiftSetupWorker?.cancel()
                    self.delayedTimeShiftSetupWorker = nil

                    self.playbackStateSubject.send(.failed)
                }
            }
        }

        private func seekRelativeTimeDidChange(_ changes: PhenixObservableChange<PhenixRequestStatusObject>?) {
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }

                guard let value = changes?.value else {
                    return
                }

                if value.status == .ok {
                    os_log(.debug, log: Self.logger, "%{private}s, Playback seek succeeded", self.alias)
                    self.playbackStateSubject.send(.seekingSucceeded)
                } else {
                    os_log(.debug, log: Self.logger, "%{private}s, Playback seek failed", self.alias)
                    self.playbackStateSubject.send(.failed)
                }
            }
        }

        private func playbackEndedDidChange(_ changes: PhenixObservableChange<NSNumber>?) {
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }

                guard let value = changes?.value else {
                    return
                }

                let didEnd = Bool(truncating: value)

                if didEnd {
                    os_log(.debug, log: Self.logger, "%{private}s, Playback ended", self.alias)
                    self.playbackStateSubject.send(.ended)
                }
            }
        }
    }
}

// MARK: - Disposable
extension PhenixCore.TimeShift: Disposable {
    func dispose() {
        os_log(.debug, log: Self.logger, "%{private}s, Dispose", alias)

        delayedTimeShiftSetupWorker?.cancel()
        delayedTimeShiftSetupWorker = nil

        playbackHeadEventDisposable = nil
        playbackStatusEventDisposable = nil
        playbackFailureEventDisposable = nil
        seekRelativeTimeEventDisposable = nil

        playbackStateSubject.send(.idle)
        playbackHeadSubject.send(0)
    }
}

// MARK: - Equatable
extension PhenixCore.TimeShift: Equatable {
    public static func == (lhs: PhenixCore.TimeShift, rhs: PhenixCore.TimeShift) -> Bool {
        lhs.alias == rhs.alias
    }
}

// MARK: - Hashable
extension PhenixCore.TimeShift: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(alias)
    }
}

// MARK: - Helpers
fileprivate extension PhenixCore.TimeShift {
    var isReadyToPause: Bool {
        state == .playing
    }

    var isReadyToPlay: Bool {
        state == .ready || state == .seekingSucceeded || state == .paused || state == .ended
    }

    var isReadyToStop: Bool {
        state == .playing || state == .paused || state == .seeking || state == .seekingSucceeded || state == .ended
    }

    var isReadyToSeek: Bool {
        state == .playing || state == .paused || state == .seeking || state == .seekingSucceeded || state == .ended
    }
}
