//
// Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

public enum PhenixConfiguration {
    // swiftlint:disable force_unwrapping
    public static var backend = URL(string: "https://demo.phenixrts.com/pcast")!
    public static var channelAliases: [String] = ["CC_Rider", "multiAngle.1", "multiAngle.2", "multiAngle.3", "multiAngle.4", "multiAngle.5"]
    static let channelBandwidthLimitation: UInt64 = 400_000
}
