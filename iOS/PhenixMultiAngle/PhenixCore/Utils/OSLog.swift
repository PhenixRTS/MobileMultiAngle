//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
    // swiftlint:disable force_unwrapping
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the main Phenix manager
    static let phenixManager = OSLog(subsystem: subsystem, category: "Phenix.Core.PhenixManager")
    static let channel = OSLog(subsystem: subsystem, category: "Phenix.Core.Channel")
    static let timeShift = OSLog(subsystem: subsystem, category: "Phenix.Core.TimeShiftWorker")
    static let replayController = OSLog(subsystem: subsystem, category: "Phenix.Core.ReplayController")
    static let mediaController = OSLog(subsystem: subsystem, category: "Phenix.Core.MediaController")
}
