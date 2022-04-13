//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Combine
import PhenixCore

extension StreamCollectionViewController {
    final class ViewModel {
        private let core: PhenixCore
        private let session: AppSession

        private var device: UIDevice = .current
        private var channelListEventCancellable: AnyCancellable?
        private var channelEventsCancellables: Set<AnyCancellable> = []

        let channelsPublisher: AnyPublisher<[PhenixCore.Channel], Never>

        init(core: PhenixCore, session: AppSession) {
            self.core = core
            self.session = session
            self.channelsPublisher = core.channelsPublisher
        }

        func select(_ channel: PhenixCore.Channel) {
            if let previousChannel = core.channels.first(where: \.isSelected) {
                core.selectChannel(alias: previousChannel.alias, isSelected: false)
            }

            core.selectChannel(alias: channel.alias, isSelected: true)
        }

        func subscribeForChannelListEvents() {
            channelListEventCancellable = core.channelsPublisher
                .sink { [weak self] channels in
                    guard let self = self else {
                        return
                    }

                    self.channelEventsCancellables.removeAll()

                    channels.forEach { channel in
                        Publishers.CombineLatest(channel.statePublisher, channel.isSelectedPublisher)
                            .sink { [weak self, weak channel] _ in
                                guard let self = self, let channel = channel else {
                                    return
                                }

                                self.refreshChannelState(channel)
                            }
                            .store(in: &self.channelEventsCancellables)
                    }
                }
        }

        func refreshBandwidthLimitation() {
            core.channels.forEach(setChannelBandwidthLimitation)
        }

        // MARK: - Private methods

        private func setChannelAudio(_ channel: PhenixCore.Channel, enabled: Bool) {
            core.setAudioEnabled(alias: channel.alias, enabled: enabled)
        }

        private func refreshChannelState(_ channel: PhenixCore.Channel) {
            setChannelAudio(channel, enabled: channel.state == .streaming && channel.isSelected)
            setChannelBandwidthLimitation(channel)
        }

        private func setChannelBandwidthLimitation(_ channel: PhenixCore.Channel) {
            switch (channel.isSelected, device.orientation.isLandscape) {
            case (true, true):
                core.removeBandwidthLimitation(alias: channel.alias)

            case (true, false):
                core.setBandwidthLimitation(alias: channel.alias, bandwidth: Self.mainPreviewBandwidth)

            case (false, true):
                core.setBandwidthLimitation(alias: channel.alias, bandwidth: Self.offscreenBandwidth)

            case (false, false):
                core.setBandwidthLimitation(alias: channel.alias, bandwidth: Self.thumbnailBandwidth)
            }
        }
    }
}

fileprivate extension StreamCollectionViewController.ViewModel {
    static var mainPreviewBandwidth: UInt64 = 1_200_000
    static let thumbnailBandwidth: UInt64 = 735_000
    static let offscreenBandwidth: UInt64 = 1_000
}
