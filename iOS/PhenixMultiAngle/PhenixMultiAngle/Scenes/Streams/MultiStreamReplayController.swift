//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixCore
import os.log

class MultiStreamReplayController {
    typealias State = ChannelReplayController.State

    private weak var channelProvider: ChannelProvider!
    private(set) var inReplayMode = false

    let availableConfigurations: [ReplayConfiguration] = [.far, .near, .close]
    var configuration: ReplayConfiguration = .far {
        didSet { configurePlayback(with: configuration) }
    }

    var state: State = .loading {
        didSet {
            if oldValue != state {
                channelProvider.replayStateDidChange(state)
            }
        }
    }

    init(channelProvider: ChannelProvider) {
        self.channelProvider = channelProvider
    }

    func playStreamsIfPossible() {
        guard state == .readyToPlay else { return }
        playStreams()
    }

    func playStreams() {
        channelProvider.channels.forEachReplay(withState: .readyToPlay) { $0.startReplay() }
        channelProvider.selectedChannel?.replay?.startObservingPlaybackHead()

        inReplayMode = true

        updateState()
    }

    func stopStreams() {
        channelProvider.channels.forEachReplay(withState: .seeking) { $0.stopReplay() }
        channelProvider.channels.forEachReplay(withState: .playing) { $0.stopReplay() }

        inReplayMode = false

        updateState()
    }

    func continuePlayingStreamsIfPossible() {
        guard state == .readyToPlay else { return }
        channelProvider.channels.forEachReplay(withState: .readyToPlay) { $0.continueReplay() }

        inReplayMode = true

        updateState()
    }

    func movePlayback(by timeInterval: TimeInterval) {
        channelProvider.channels.forEachReplay(withState: .playing) { $0.movePlaybackHead(by: timeInterval) }
    }

    func configurePlayback(with replayConfiguration: ReplayConfiguration) {
        os_log(.debug, log: .ui, "Change replay configuration to %{PRIVATE}s", replayConfiguration.title)
        let date = Date()

        for channel in channelProvider.channels {
            channel.setReplay(toStartAt: date, with: replayConfiguration)
        }
    }

    func updateState() {
        var replays = channelProvider.channels.compactMap { $0.replay }

        if replays.allSatisfy({ $0.state == .failure }) {
            state = .failure
            return
        }

        replays = replays.filter { $0.state != .failure }

        if replays.allSatisfy({ $0.state == .playing }) {
            state = .playing
            return
        }

        if replays.contains(where: { $0.state == .loading }) {
            state = .loading
            return
        }

        if replays.contains(where: { $0.state == .seeking }) {
            state = .seeking
            return
        }

        if replays.contains(where: { $0.state == .readyToPlay }) {
            state = .readyToPlay
            return
        }

        state = .ended
    }
}

// MARK: - ChannelTimeShiftObserver
extension MultiStreamReplayController: ChannelTimeShiftObserver {
    func channel(_ channel: Channel, didChange state: ChannelReplayController.State) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.updateState()

            if self.inReplayMode {
                self.playStreamsIfPossible()
            }

            guard state == .playing else { return }
            guard channel == self.channelProvider.selectedChannel else { return }

            channel.media?.setAudio(enabled: true)
            channel.replay?.startObservingPlaybackHead()
        }
    }

    func channel(_ channel: Channel, didChangePlaybackHeadTo currentDate: Date, startDate: Date, endDate: Date) {
        // Don't do anything
    }
}

// MARK: - Helpers
extension Sequence where Element == Channel {
    func forEachReplay(withState state: ChannelReplayController.State, do handle: (ChannelReplayController) -> Void) {
        let replays = compactMap { $0.replay }

        for replay in replays where replay.state == state {
            handle(replay)
        }
    }
}
