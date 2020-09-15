//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

public struct PhenixClosedCaptionMessage: Codable {
    public var textUpdates: [PhenixTextUpdate]
}

extension PhenixClosedCaptionMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        "PhenixClosedCaptionMessage(textUpdates: \(textUpdates))"
    }
}
