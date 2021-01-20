//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public struct PhenixBandwidthLimit: RawRepresentable {
    public var rawValue: UInt64

    public init?(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

extension PhenixBandwidthLimit: CustomStringConvertible {
    public var description: String {
        "PhenixBandwidthLimit(\(rawValue))"
    }
}
