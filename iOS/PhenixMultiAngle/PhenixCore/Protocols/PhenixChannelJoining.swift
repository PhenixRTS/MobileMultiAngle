//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
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
        queue.async { [weak self] in
            guard let self = self else { return }
            let rendererOptions = PhenixRendererOptions()
            let roomOptions = RoomOptionsFactory.makeJoinRoomOptions(
                configuration: self.configuration,
                alias: channel.alias
            )

            let channelOptions = ChannelOptionsFactory.makeJoinChannelOptions(
                configuration: self.configuration,
                joinRoomOptions: roomOptions,
                rendererLayer: channel.primaryPreviewLayer,
                rendererOptions: rendererOptions
            )

            os_log(.debug, log: .phenixManager, "Joining a room with options", channelOptions.description)

            self.join(channel, with: channelOptions)
        }
    }
}

fileprivate extension PhenixManager {
    private func join(_ channel: Channel, with options: PhenixJoinChannelOptions) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let channelExpress = self.channelExpress else {
            fatalError("Must call PhenixManager.start() before this method")
        }

        // swiftlint:disable multiline_arguments
        channelExpress.joinChannel(options, { status, roomService in
            os_log(
                .debug,
                log: .phenixManager,
                "Join channel callback received with status: %{PUBLIC}d, %{PRIVATE}s",
                status.rawValue,
                channel.description
            )
            channel.joinChannelHandler(status: status, roomService: roomService)
        }) { status, subscriber, renderer in
            os_log(
                .debug,
                log: .phenixManager,
                "Channel stream subscription callback received with status: %{PUBLIC}d, %{PRIVATE}s",
                status.rawValue,
                channel.description
            )
            channel.subscriberHandler(status: status, subscriber: subscriber, renderer: renderer)
        }
    }
}
