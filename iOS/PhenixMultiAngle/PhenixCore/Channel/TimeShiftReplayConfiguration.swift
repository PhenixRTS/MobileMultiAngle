//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public struct TimeShiftReplayConfiguration {
    public let id: Int
    public let title: String
    public let playbackDuration: TimeInterval // In seconds
    let playbackStartPoint: DateComponents
}

public extension TimeShiftReplayConfiguration {
    static let far = TimeShiftReplayConfiguration(id: 1, title: "FAR", playbackDuration: 30, playbackStartPoint: DateComponents(second: -40))
    static let near = TimeShiftReplayConfiguration(id: 2, title: "NEAR", playbackDuration: 20, playbackStartPoint: DateComponents(second: -30))
    static let close = TimeShiftReplayConfiguration(id: 3, title: "CLOSE", playbackDuration: 10, playbackStartPoint: DateComponents(second: -20))
}
