//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixSdk

internal protocol ReplayDelegate: AnyObject {
    func replayDidChangeState(_ state: ChannelTimeShiftWorker.TimeShiftState)
    func replayDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date)
}

public class ChannelReplayController {
    private static let retryDelay: TimeInterval = 10
    private static let timeout: TimeInterval = 20

    private weak var renderer: PhenixRenderer!
    private var worker: ChannelTimeShiftWorker?
    private var options: Options
    private var maxRetryCount: Int
    private var retries: Int
    private var isSubscribed: Bool
    private var delayedTimeShiftSetupWorkItem: DispatchWorkItem?
    private var stateChangeTimeoutWorkItem: DispatchWorkItem?

    internal weak var channelRepresentation: ChannelRepresentation?
    internal weak var delegate: ReplayDelegate?

    public var state: ChannelTimeShiftWorker.TimeShiftState = .starting {
        didSet { stateDidChange(state) }
    }

    init(renderer: PhenixRenderer, options: Options, channelRepresentation: ChannelRepresentation? = nil) {
        self.renderer = renderer
        self.options = options
        self.maxRetryCount = Int(options.configuration.playbackDuration / Self.retryDelay)
        self.retries = 0
        self.isSubscribed = false
        self.channelRepresentation = channelRepresentation

        self.setupTimeShift()
    }

    public func subscribe() {
        os_log(.debug, log: .replayController, "Subscribe for time shift worker events, (%{PRIVATE}s)", channelDescription)
        isSubscribed = true
        worker?.subscribeForStatusEvents()
    }

    public func startReplay() {
        os_log(.debug, log: .replayController, "Start replay, (%{PRIVATE}s)", channelDescription)
        worker?.startReplay()
    }

    public func stopReplay() {
        os_log(.debug, log: .replayController, "Stop replay, (%{PRIVATE}s)", channelDescription)
        // To stop TimeShift, dispose instance of it and create new one.
        resetRetryCount()
        setupTimeShift()
    }

    public func startObservingPlaybackHead() {
        os_log(.debug, log: .replayController, "Observe playback, (%{PRIVATE}s)", channelDescription)
        worker?.subscribeForPlaybackHeadEvents()
    }

    public func stopObservingPlaybackHead() {
        os_log(.debug, log: .replayController, "Stop observing playback, (%{PRIVATE}s)", channelDescription)
        worker?.unsubscribeForPlaybackHeadEvents()
    }

    public func movePlaybackHead(by time: TimeInterval) {
        os_log(.debug, log: .replayController, "Move playback head to %{PRIVATE}s in timeline, (%{PRIVATE}s)", time.description, channelDescription)
        worker?.movePlaybackHead(by: time)
    }

    public func limitBandwidth(at bandwidth: PhenixBandwidthLimit) {
        os_log(.debug, log: .replayController, "Limit bandwidth at %{PRIVATE}s, (%{PRIVATE}s)", bandwidth.description, channelDescription)
        worker?.limitBandwidth(at: bandwidth)
    }

    public func removeBandwidthLimitation() {
        os_log(.debug, log: .replayController, "Remove bandwidth limitation, (%{PRIVATE}s)", channelDescription)
        worker?.stopBandwidthLimitation()
    }

    deinit {
        worker?.dispose()
        worker = nil
    }
}

// MARK: - Internal methods
internal extension ChannelReplayController {
    struct Options: CustomStringConvertible {
        var configuration: ReplayConfiguration
        var startDate: Date

        var description: String {
            "Options(startDate: \(startDate.description), configuration: \(configuration))"
        }
    }
}

// MARK: - Private methods
private extension ChannelReplayController {
    var channelDescription: String { channelRepresentation?.alias ?? "-" }

    func setupTimeShift() {
        os_log(.debug, log: .replayController, "Setup TimeShift worker, (%{PRIVATE}s)", channelDescription)
        do {
            state = .starting

            // Always before creating a new TimeShift worker, previous worker must call `dispose` method.
            worker?.dispose()

            os_log(.debug, log: .replayController, "TimeShift worker options: %{PRIVATE}s, (%{PRIVATE}s)", options.description, channelDescription)

            let worker = try ChannelTimeShiftWorker(renderer: renderer, initialDateTime: options.startDate, configuration: options.configuration)
            self.worker = worker
            worker.channelRepresentation = channelRepresentation
            worker.delegate = self

            state = worker.state

            if isSubscribed {
                // If app was already subscribed for the TimeShift previously, we need to automatically re-subscribe if TimeShift worker gets re-created.
                subscribe()
            }
        } catch {
            os_log(.debug, log: .replayController, "Failed to setup TimeShift worker, (%{PRIVATE}s)", channelDescription)
            state = .failure
        }
    }

    func processTimeShiftFailure() {
        os_log(.debug, log: .replayController, "Process TimeShift failure, (%{PRIVATE}s)", channelDescription)
        guard retries < maxRetryCount else {
            os_log(.debug, log: .replayController, "Max retries (%{PRIVATE}d) exceeded, (%{PRIVATE}s)", retries, channelDescription)
            state = .failure
            return
        }

        guard delayedTimeShiftSetupWorkItem == nil else {
            os_log(.debug, log: .replayController, "Already waiting for retry TimeShift setup, (%{PRIVATE}s)", channelDescription)
            return
        }

        retries += 1
        state = .starting

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }

            os_log(.debug, log: .replayController, "Retry to setup TimeShift (%{PRIVATE}d/%{PRIVATE}d), (%{PRIVATE}s)", self.retries, self.maxRetryCount, self.channelDescription)
            self.setupTimeShift()
            self.subscribe()
            self.delayedTimeShiftSetupWorkItem = nil
        }

        delayedTimeShiftSetupWorkItem = workItem

        os_log(.debug, log: .replayController, "Start retry setup TimeShift timer countdown, (%{PRIVATE}s)", channelDescription)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay, execute: workItem)
    }

    func stateDidChange(_ state: ChannelTimeShiftWorker.TimeShiftState) {
        os_log(.debug, log: .replayController, "TimeShift state did change to %{PRIVATE}s, (%{PRIVATE}s)", String(describing: state), channelDescription)
        // Reset timeout counter
        resetConnectionTimeoutCountdown()

        if state != .starting && state != .failure {
            // Only reset the retry counter when the app is ready to play replay.
            resetRetryCount()
        }

        if state == .starting {
            // In case, if the state `.starting` does not change to different state in specific amount of time, consider that the TimeShift has reached timeout and set the state to `.failure`.
            startConnectionTimeoutCountdown()
        }

        delegate?.replayDidChangeState(state)
    }

    func startConnectionTimeoutCountdown() {
        os_log(.debug, log: .replayController, "Start connection timer countdown, (%{PRIVATE}s)", channelDescription)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }

            os_log(.debug, log: .replayController, "Set connection state to failure because of timeout, (%{PRIVATE}s)", self.channelDescription)
            self.state = .failure
        }

        stateChangeTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout, execute: workItem)
    }

    func resetConnectionTimeoutCountdown() {
        os_log(.debug, log: .replayController, "Reset connection timer countdown, (%{PRIVATE}s)", channelDescription)
        stateChangeTimeoutWorkItem?.cancel()
        stateChangeTimeoutWorkItem = nil
    }

    func resetRetryCount() {
        os_log(.debug, log: .replayController, "Reset retry count, (%{PRIVATE}s)", channelDescription)
        retries = 0
    }
}

// MARK: - TimeShiftDelegate
extension ChannelReplayController: TimeShiftDelegate {
    func timeShiftDidFail() {
        processTimeShiftFailure()
    }

    func timeShiftDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date) {
        delegate?.replayDidChangePlaybackHead(startDate: startDate, currentDate: currentDate, endDate: endDate)
    }

    func timeShiftDidChangeState(_ state: ChannelTimeShiftWorker.TimeShiftState) {
        self.state = state
    }
}
