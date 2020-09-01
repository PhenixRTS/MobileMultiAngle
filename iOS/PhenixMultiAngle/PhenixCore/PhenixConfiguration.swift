//
// Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import PhenixSdk

public enum PhenixConfiguration {
    // swiftlint:disable force_unwrapping
    public static var backend = URL(string: "https://demo.phenixrts.com/pcast")!
    public static var channelAliases: [String] = ["NFL.1", "NFL.2", "NFL.3", "NFL.4", "NFL.5"]
}
