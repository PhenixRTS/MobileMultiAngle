//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

// swiftlint:disable line_length

import Foundation
import PhenixSdk

public struct PhenixConfiguration: Equatable {
    /// Phenix backend url.
    public var backend: URL?

    /// Phenix PCast url.
    public var pcast: URL?

    /// Phenix edge token.
    ///
    /// If token is provided, then backend url will be ignored and also capabilities will be ignored when configuring the room publisher options.
    public var edgeToken: String?

    /// Each stream token corresponds to the channel alias array at the same index position.
    public var streamTokens: [String]

    /// Capabilities for room subscription.
    public var capabilities: [String]

    public var channelAliases: [String]

    public var logLevel: LogLevel = .off

    public init(
        backend: URL? = nil,
        edgeToken: String? = nil,
        pcast: URL? = nil,
        capabilities: [String] = [],
        channelAliases: [String],
        streamTokens: [String],
        logLevel: LogLevel
    ) {
        self.backend = backend
        self.pcast = pcast
        self.edgeToken = edgeToken
        self.capabilities = capabilities
        self.channelAliases = channelAliases
        self.streamTokens = streamTokens
        self.logLevel = logLevel
    }
}

public extension PhenixConfiguration {
    static let `default` = PhenixConfiguration(
        backend: URL(string: "https://demo-stg.phenixrts.com/pcast"),
        pcast: URL(string: "https://pcast-stg.phenixrts.com"),
        capabilities: ["time-shift"],
        channelAliases: [
            "MultiAngle.1_720p60",
            "MultiAngle.2_720p60",
            "MultiAngle.3_720p60",
            "MultiAngle.4_720p60",
            "MultiAngle.5_720p60"
        ],
        streamTokens: [],
        logLevel: .debug
    )
}
