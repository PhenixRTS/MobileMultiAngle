//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

final class Throttler {
    private let delay: TimeInterval
    private var lastExecutionDate: Date?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func run(block: () -> Void) {
        // Check if the last execution date exists, if not, this is the first time when the code gets executed.
        guard let lastExecutionDate = lastExecutionDate else {
            self.lastExecutionDate = Date()
            block()
            return
        }

        // Compare current date with the last execution date appended with the delay time.
        guard Date() > lastExecutionDate.addingTimeInterval(delay) else {
            // Delay time hasn't passed, do not run the block of code
            return
        }

        // Delay since last execution has passed, execute the block of code
        self.lastExecutionDate = Date()
        block()
    }
}
