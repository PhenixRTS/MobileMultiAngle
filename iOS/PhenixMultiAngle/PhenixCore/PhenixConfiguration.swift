//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

// swiftlint:disable force_unwrapping
public enum PhenixConfiguration {
    public static var backend = URL(string: "https://demo-stg.phenixrts.com/pcast")!
    public static var pcast: URL? = URL(string: "https://pcast-stg.phenixrts.com")
    public static var channelAliases: [String] = ["MultiAngle.1_720p60", "MultiAngle.2_720p60", "MultiAngle.3_720p60", "MultiAngle.4_720p60", "MultiAngle.5_720p60"]
}

public extension PhenixBandwidthLimit {
    static var hero: Self { PhenixBandwidthLimit(rawValue: 1_200_000)! }
    static var thumbnail: Self { PhenixBandwidthLimit(rawValue: 735_000)! }
    static var offscreen: Self { PhenixBandwidthLimit(rawValue: 1_000)! }
}
