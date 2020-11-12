//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public struct ReplayConfiguration {
    public let id: Int
    public let title: String
    public let playbackDuration: TimeInterval // In seconds
    let playbackStartPoint: DateComponents
}

public extension ReplayConfiguration {
    static let far = ReplayConfiguration(id: 1, title: "FAR", playbackDuration: 40, playbackStartPoint: DateComponents(second: -60))
    static let near = ReplayConfiguration(id: 2, title: "NEAR", playbackDuration: 20, playbackStartPoint: DateComponents(second: -30))
    static let close = ReplayConfiguration(id: 3, title: "CLOSE", playbackDuration: 10, playbackStartPoint: DateComponents(second: -10))
}
