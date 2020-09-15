//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public struct PhenixTextUpdate: Codable {
    public var timestamp: TimeInterval
    public var caption: String
}

extension PhenixTextUpdate: CustomDebugStringConvertible {
    public var debugDescription: String {
        "PhenixTextUpdate(timestamp: \"\(timestamp)\", caption: \(caption))"
    }
}
