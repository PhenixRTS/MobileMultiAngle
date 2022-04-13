//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Combine
import Foundation
import PhenixCore

extension StreamCollectionViewCell {
    class ViewModel {
        private let core: PhenixCore
        private let channel: PhenixCore.Channel

        private var channelStateCancellable: AnyCancellable?
        private var channelSelectionCancellable: AnyCancellable?

        var getPreviewLayer: (() -> CALayer?)?
        var onChannelStateChange: ((PhenixCore.Channel.State) -> Void)?
        var onChannelSelectionChange: ((Bool) -> Void)?

        init(core: PhenixCore, channel: PhenixCore.Channel) {
            self.core = core
            self.channel = channel
        }

        func subscribeForEvents() {
            channelStateCancellable = channel.statePublisher
                .sink { [weak self] state in
                    self?.onChannelStateChange?(state)
                }

            channelSelectionCancellable = channel.isSelectedPublisher
                .sink { [weak self] isSelected in
                    self?.channelSelectionDidChange(isSelected)
                }
        }

        private func rendererPreview(layer: CALayer) {
            if channel.isSelected {
                core.renderThumbnailVideo(alias: channel.alias, layer: layer)
            } else {
                core.renderVideo(alias: channel.alias, layer: layer)
            }
        }

        private func channelSelectionDidChange(_ isSelected: Bool) {
            if let layer = getPreviewLayer?() {
                rendererPreview(layer: layer)
            }

            onChannelSelectionChange?(isSelected)
        }
    }
}
