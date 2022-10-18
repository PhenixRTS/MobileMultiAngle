//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Combine
import Foundation
import os.log
import PhenixClosedCaptions
import PhenixCore

extension StreamViewController {
    class ViewModel {
        private static let logger = OSLog(identifier: "StreamViewController.ViewModel")

        private static var dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            return formatter
        }()

        private let core: PhenixCore
        private let session: AppSession
        private let closedCaptions: PhenixClosedCaptionsController
        private let closedCaptionsChannelAlias: String?

        private var channelsEventCancellable: AnyCancellable?
        private var channelStateEventCancellables: Set<AnyCancellable> = []
        private var channelSelectionEventCancellables: Set<AnyCancellable> = []
        private var channelTimeShiftStatesCancellable: AnyCancellable?
        private var selectedChannelTimeShiftHeadCancellable: AnyCancellable?
        private var selectedChannelTimeShiftStateCancellable: AnyCancellable?

        private var replayCreationDate: Date?

        // MARK: - Subscribers
        private let selectedChannelReplayDateSubject = PassthroughSubject<String, Never>()
        private let selectedChannelReplayHeadSubject = PassthroughSubject<TimeInterval, Never>()
        private let selectedChannelReplayStateSubject = CurrentValueSubject<PhenixCore.TimeShift.State, Never>(.idle)

        // MARK: - Publishers
        lazy var selectedChannelReplayDatePublisher = selectedChannelReplayDateSubject.eraseToAnyPublisher()
        lazy var selectedChannelReplayHeadPublisher = selectedChannelReplayHeadSubject.eraseToAnyPublisher()
        lazy var selectedChannelReplayStatePublisher = selectedChannelReplayStateSubject.eraseToAnyPublisher()

        var replayModes: [Replay] { session.replayModes }

        private(set) var selectedReplayMode: Replay {
            get { session.selectedReplayMode }
            set { session.selectedReplayMode = newValue }
        }

        var isClosedCaptionsEnabled: Bool {
            get { closedCaptions.isEnabled }
            set { closedCaptions.isEnabled = newValue }
        }

        var getPreviewLayer: (() -> CALayer?)?

        init(core: PhenixCore, session: AppSession, closedCaptions: PhenixClosedCaptionsController) {
            self.core = core
            self.session = session
            self.closedCaptions = closedCaptions

            self.closedCaptionsChannelAlias = session.configurations.first?.alias
        }

        func joinToChannels() {
            for configuration in session.configurations {
                core.joinToChannel(configuration: configuration)
            }
        }

        func subscribeForClosedCaptions(_ view: PhenixClosedCaptionsView) {
            guard let alias = closedCaptionsChannelAlias else {
                return
            }

            closedCaptions.setContainerView(view)
            closedCaptions.subscribeForChannelMessages(alias: alias)
        }

        func subscribeForChannelListEvents() {
            channelsEventCancellable = core.channelsPublisher
                .sink { [weak self] channels in
                    guard let self = self else {
                        return
                    }

                    self.channelStateEventCancellables.removeAll()
                    self.channelSelectionEventCancellables.removeAll()

                    self.channelTimeShiftStatesCancellable = Publishers
                        .MergeMany(channels.map(\.timeShiftStatePublisher))
                        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        .sink { [weak self] _ in
                            guard let self = self else {
                                return
                            }

                            self.channelTimeShiftStateDidChange(self.core.channels)
                        }

                    if let channel = channels.first {
                        self.core.selectChannel(alias: channel.alias, isSelected: true)
                    }

                    channels.forEach {
                        self.subscribeForChannelStateEvents($0)
                        self.subscribeForChannelSelectionEvents($0)
                    }
                }
        }

        func selectReplayMode(_ replay: Replay) {
            selectedReplayMode = replay
            setReplayStartDate()

            core.channels.forEach { channel in
                createTimeShift(channel)
            }
        }

        func startReplay() {
            core.channels
                .filter { $0.timeShiftState == .ready }
                .forEach { [weak self] channel in
                    self?.playTimeShiftLoop(channel)
                }
        }

        func stopReplay() {
            core.channels
                .forEach { [weak self] channel in
                    self?.stopTimeShift(channel)
                }
        }

        func moveReplay(offset: TimeInterval) {
            core.channels
                .filter { $0.timeShiftStateIsActive }
                .forEach { [weak self] channel in
                    self?.seekTimeShift(channel, offset: offset)
                }
        }

        // MARK: - Private methods

        private func subscribeForChannelSelectionEvents(_ channel: PhenixCore.Channel) {
            channel.isSelectedPublisher
                .sink { [weak self, weak channel] isSelected in
                    guard let self = self, let channel = channel else {
                        return
                    }

                    if isSelected {
                        self.selectedChannelDidChange(channel)
                    }
                }
                .store(in: &channelSelectionEventCancellables)
        }

        private func subscribeForChannelStateEvents(_ channel: PhenixCore.Channel) {
            channel.statePublisher
                .sink { [weak self, weak channel] state in
                    guard let self = self, let channel = channel else {
                        return
                    }

                    self.channelStateDidChange(state, channel: channel)
                }
                .store(in: &channelStateEventCancellables)
        }

        private func selectedChannelDidChange(_ channel: PhenixCore.Channel) {
            let layer = getPreviewLayer?()
            core.renderVideo(alias: channel.alias, layer: layer)
            subscribeForChannelTimeShiftStateEvents(channel)
            subscribeForChannelTimeShiftHeadEvents(channel)
        }

        private func channelTimeShiftStateDidChange(_ channels: [PhenixCore.Channel]) {
            // Gather all of the streams which succeeded to seek and now are ready to play.
            // Then just start playing them.
            channels
                .filter { $0.timeShiftState == .seekingSucceeded }
                .forEach(self.playTimeShift)
        }

        private func setReplayStartDate() {
            replayCreationDate = Date().advanced(by: selectedReplayMode.seek)
        }

        private func channelStateDidChange(_ state: PhenixCore.Channel.State, channel: PhenixCore.Channel) {
            if state == .streaming {
                setReplayStartDate()
                createTimeShift(channel)
            }
        }

        private func subscribeForChannelTimeShiftStateEvents(_ channel: PhenixCore.Channel) {
            selectedChannelTimeShiftStateCancellable = channel.timeShiftStatePublisher
                .sink { [weak self] state in
                    self?.selectedChannelReplayStateSubject.send(state)
                }
        }

        private func subscribeForChannelTimeShiftHeadEvents(_ channel: PhenixCore.Channel) {
            selectedChannelTimeShiftHeadCancellable = channel.timeShiftHeadPublisher
                .sink { [weak self] timeInterval in
                    guard let self = self else {
                        return
                    }

                    self.selectedChannelReplayHeadSubject.send(timeInterval)

                    if let date = self.replayCreationDate {
                        let dateString = self.replayDate(from: date.advanced(by: timeInterval))
                        self.selectedChannelReplayDateSubject.send(dateString)
                    }
                }
        }

        private func replayDate(from date: Date) -> String {
            Self.dateFormatter.string(from: date)
        }

        private func createTimeShift(_ channel: PhenixCore.Channel) {
            if let date = replayCreationDate {
                core.createTimeShift(alias: channel.alias, on: .timestamp(date))
            }
        }

        private func playTimeShift(_ channel: PhenixCore.Channel) {
            core.playTimeShift(alias: channel.alias)
        }

        private func playTimeShiftLoop(_ channel: PhenixCore.Channel) {
            core.playTimeShift(alias: channel.alias, loop: selectedReplayMode.duration)
        }

        private func stopTimeShift(_ channel: PhenixCore.Channel) {
            core.stopTimeShift(alias: channel.alias)
        }

        private func seekTimeShift(_ channel: PhenixCore.Channel, offset: TimeInterval) {
            core.seekTimeShift(alias: channel.alias, offset: offset)
        }
    }
}

fileprivate extension PhenixCore.Channel {
    var timeShiftStateIsActive: Bool {
        timeShiftState == .playing
        || timeShiftState == .paused
        || timeShiftState == .seeking
        || timeShiftState == .seekingSucceeded
    }
}
