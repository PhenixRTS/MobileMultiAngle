//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

// swiftlint:disable force_unwrapping

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

public extension PhenixBandwidthLimit {
    static var hero: Self { PhenixBandwidthLimit(rawValue: 1_200_000)! }
    static var thumbnail: Self { PhenixBandwidthLimit(rawValue: 735_000)! }
    static var offscreen: Self { PhenixBandwidthLimit(rawValue: 1_000)! }
}
