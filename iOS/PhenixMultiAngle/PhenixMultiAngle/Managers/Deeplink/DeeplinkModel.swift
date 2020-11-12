//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public struct DeeplinkModel: DeeplinkModelProvider {
    var channelAliases: [String]?
    var uri: URL?
    var backend: URL?

    public init?(components: URLComponents) {
        if let string = components.queryItems?.first(where: { $0.name == "channelAliases" })?.value {
            self.channelAliases = string
                .split(separator: ",")
                .map(String.init)
        }

        if let string = components.queryItems?.first(where: { $0.name == "uri" })?.value {
            self.uri = URL(string: string)
        }

        if let string = components.queryItems?.first(where: { $0.name == "backend" })?.value {
            self.backend = URL(string: string)
        }
    }
}
