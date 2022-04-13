//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

struct Replay {
    var title: String
    var seek: TimeInterval
    var duration: TimeInterval

    static let far = Replay(title: "FAR", seek: -120, duration: 40)
    static let near = Replay(title: "NEAR", seek: -60, duration: 30)
    static let close = Replay(title: "CLOSE", seek: -30, duration: 20)
}
