//
// Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

public protocol PhenixChannelJoining: AnyObject {
    /// Connects to channel and its stream
    /// - Parameters:
    ///   - channel: Channel which will be joined
    func join(_ channel: Channel)
}

extension PhenixManager: PhenixChannelJoining {
    public func join(_ channel: Channel) {
        privateQueue.async { [weak self] in
            guard let self = self else { return }
            let rendererOptions = PhenixRendererOptions()
            let joinRoomOptions = PhenixOptionBuilder.createJoinRoomOptions(withAlias: channel.alias)
            let joinChannelOptions = PhenixOptionBuilder.createJoinChannelOptions(with: joinRoomOptions, rendererLayer: channel.primaryPreviewLayer, rendererOptions: rendererOptions)
            os_log(.debug, log: .phenixManager, "Joining a room with options", joinChannelOptions.description)
            self.join(channel, with: joinChannelOptions)
        }
    }
}

fileprivate extension PhenixManager {
    private func join(_ channel: Channel, with options: PhenixJoinChannelOptions) {
        dispatchPrecondition(condition: .onQueue(privateQueue))
        precondition(channelExpress != nil, "Must call PhenixManager.start() before this method")
        // swiftlint:disable multiline_arguments
        channelExpress.joinChannel(options) { status, roomService in
            os_log(.debug, log: .phenixManager, "Join channel callback received with status: %{PUBLIC}d, %{PRIVATE}s", status.rawValue, channel.description)
            channel.joinChannelHandler(status: status, roomService: roomService)
        } _: { status, subscriber, renderer in
            os_log(.debug, log: .phenixManager, "Channel stream subscription callback received with status: %{PUBLIC}d, %{PRIVATE}s", status.rawValue, channel.description)
            channel.subscriberHandler(status: status, subscriber: subscriber, renderer: renderer)
        }
    }
}
