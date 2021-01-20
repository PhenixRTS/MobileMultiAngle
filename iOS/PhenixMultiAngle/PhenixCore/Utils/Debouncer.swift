//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

final class Debouncer {
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var worker: DispatchWorkItem?

    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    func run(block: @escaping () -> Void) {
        worker?.cancel()
        let worker = DispatchWorkItem(block: block)
        self.worker = worker
        queue.asyncAfter(deadline: .now() + delay, execute: worker)
    }

    func invalidate() {
        worker?.cancel()
        worker = nil
    }
}
