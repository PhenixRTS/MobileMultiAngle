//
// Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

// swiftlint:disable force_unwrapping
public enum PhenixConfiguration {
    public static var backend = URL(string: "https://demo.phenixrts.com/pcast")!
    public static var pcast: URL?
    public static var channelAliases: [String] = ["CC_Rider", "multiAngle.1", "multiAngle.2", "multiAngle.3", "multiAngle.4", "multiAngle.5"]
}

public extension PhenixBandwidthLimit {
    static var hero: Self { PhenixBandwidthLimit(rawValue: 1_200_000)! }
    static var thumbnail: Self { PhenixBandwidthLimit(rawValue: 735_000)! }
    static var offscreen: Self { PhenixBandwidthLimit(rawValue: 1_000)! }
}
