//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixDeeplink
import PhenixCore

class AppSession {
    enum ConfigurationError: Error {
        case missingMandatoryDeeplinkProperties
        case mismatch
        case mismatchAliasAndStreamTokenCount
    }

    private var aliases: [String]
    private var streamTokens: [String]

    private(set) var authToken: String
    private(set) var configurations: [PhenixCore.Channel.Configuration]

    let replayModes: [Replay] = [.far, .near, .close]
    var selectedReplayMode: Replay = .close

    init(deeplink: PhenixDeeplinkModel) throws {
        guard let authToken = deeplink.authToken,
              let aliases = deeplink.channelAliases,
              let streamTokens = deeplink.channelStreamTokens else {
                  throw ConfigurationError.missingMandatoryDeeplinkProperties
              }

        guard aliases.count == streamTokens.count else {
            throw ConfigurationError.mismatchAliasAndStreamTokenCount
        }

        self.aliases = aliases
        self.authToken = authToken
        self.streamTokens = streamTokens
        self.configurations = zip(aliases, streamTokens).map { (alias, token) in
            PhenixCore.Channel.Configuration(alias: alias, streamToken: token, videoAspectRatio: .fit)
        }
    }

    func validate(_ deeplink: PhenixDeeplinkModel) throws {
        if let value = deeplink.authToken, value != authToken {
            throw ConfigurationError.mismatch
        }

        if let value = deeplink.channelAliases, value != aliases {
            throw ConfigurationError.mismatch
        }

        if let value = deeplink.channelStreamTokens, value != streamTokens {
            throw ConfigurationError.mismatch
        }
    }
}

extension AppSession: Equatable {
    static func == (lhs: AppSession, rhs: AppSession) -> Bool {
        lhs.authToken == rhs.authToken
        && lhs.streamTokens == rhs.streamTokens
        && lhs.aliases == rhs.aliases
    }
}
