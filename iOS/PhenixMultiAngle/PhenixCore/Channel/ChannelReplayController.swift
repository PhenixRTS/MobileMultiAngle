//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixSdk

internal protocol ReplayDelegate: AnyObject {
    func replayDidChangeState(_ state: ChannelReplayController.State)
    func replayDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date)
}

public class ChannelReplayController {
    private static let retryDelay: TimeInterval = 10
    private static let timeout: TimeInterval = 20

    private weak var renderer: PhenixRenderer!
    private var worker: TimeShiftWorker?
    private var options: Options
    private var maxRetryCount: Int
    private var retries: Int
    private var isSubscribed: Bool
    private var delayedTimeShiftSetupWorkItem: DispatchWorkItem?
    private var stateChangeTimeoutWorkItem: DispatchWorkItem?

    internal weak var channelRepresentation: ChannelRepresentation?
    internal weak var delegate: ReplayDelegate?

    public var state: State = .loading {
        didSet { stateDidChange(state) }
    }

    init(renderer: PhenixRenderer, options: Options, delegate: ReplayDelegate?, channelRepresentation: ChannelRepresentation? = nil) {
        self.renderer = renderer
        self.options = options
        self.maxRetryCount = Int(options.configuration.playbackDuration / Self.retryDelay)
        self.retries = 0
        self.isSubscribed = false
        self.delegate = delegate
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

    public func continueReplay() {
        os_log(.debug, log: .replayController, "Continue replay, (%{PRIVATE}s)", channelDescription)
        worker?.continueReplay()
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
        delayedTimeShiftSetupWorkItem?.cancel()
        delayedTimeShiftSetupWorkItem = nil

        stateChangeTimeoutWorkItem?.cancel()
        stateChangeTimeoutWorkItem = nil

        worker?.dispose()
        worker = nil
    }
}

public extension ChannelReplayController {
    enum State {
        case loading
        case readyToPlay
        case playing
        case seeking
        case ended
        case failure
    }
}

// MARK: - CustomStringConvertible
extension ChannelReplayController: CustomStringConvertible {
    public var description: String {
        "Replay, timeshift: \(worker != nil ? "exists" : "-"), state: \(state), options: \(options)"
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
            state = .loading

            // Always before creating a new TimeShift worker, previous worker must call `dispose` method.
            worker?.dispose()

            os_log(.debug, log: .replayController, "TimeShift worker options: %{PRIVATE}s, (%{PRIVATE}s)", options.description, channelDescription)

            let worker = try TimeShiftWorker(renderer: renderer, initialDateTime: options.startDate, configuration: options.configuration)
            self.worker = worker
            worker.channelRepresentation = channelRepresentation
            worker.delegate = self

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
            return
        }

        guard delayedTimeShiftSetupWorkItem == nil else {
            os_log(.debug, log: .replayController, "Already waiting for retry TimeShift setup, (%{PRIVATE}s)", channelDescription)
            return
        }

        retries += 1
        state = .loading

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

    func stateDidChange(_ state: State) {
        os_log(.debug, log: .replayController, "TimeShift state did change to %{PRIVATE}s, (%{PRIVATE}s)", String(describing: state), channelDescription)
        // Reset timeout counter
        resetConnectionTimeoutCountdown()

        switch state {
        case .loading, .seeking:
            // In case, if the state `.starting` does not change to different state in specific amount of time, consider that the TimeShift has reached timeout and set the state to `.failure`.
            startConnectionTimeoutCountdown()
        case .readyToPlay, .playing, .ended:
            resetRetryCount()
        case .failure:
            processTimeShiftFailure()
        }

        delegate?.replayDidChangeState(state)
    }

    func startConnectionTimeoutCountdown() {
        os_log(.debug, log: .replayController, "Start connection timer countdown, (%{PRIVATE}s)", channelDescription)
        let workItem = DispatchWorkItem { [weak self] in
            self?.connectionTimeoutReached()
        }

        stateChangeTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout, execute: workItem)
    }

    func resetConnectionTimeoutCountdown() {
        os_log(.debug, log: .replayController, "Reset connection timer countdown, (%{PRIVATE}s)", channelDescription)
        stateChangeTimeoutWorkItem?.cancel()
        stateChangeTimeoutWorkItem = nil
    }

    func connectionTimeoutReached() {
        os_log(.debug, log: .replayController, "Connection timeout reached, (%{PRIVATE}s)", channelDescription)
        retries = maxRetryCount
        stateChangeTimeoutWorkItem = nil
        worker?.stopReplay(forceFailure: true)
    }

    func resetRetryCount() {
        os_log(.debug, log: .replayController, "Reset retry count, (%{PRIVATE}s)", channelDescription)
        retries = 0
    }
}

// MARK: - TimeShiftDelegate
extension ChannelReplayController: TimeShiftDelegate {
    func timeShiftDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date) {
        delegate?.replayDidChangePlaybackHead(startDate: startDate, currentDate: currentDate, endDate: endDate)
    }

    func timeShiftDidChangeState(_ state: TimeShiftWorker.State) {
        switch state {
        case .starting:
            self.state = .loading
        case .readyToPlay:
            self.state = .readyToPlay
        case .playing:
            self.state = .playing
        case .seeking:
            self.state = .seeking
        case .ended:
            self.state = .ended
        case .failure:
            self.state = .failure
        }
    }
}
