//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

protocol StreamViewDelegate: AnyObject {
    var isClosedCaptionsEnabled: Bool { get }

    func streamViewDidToggleClosedCaptions(_ view: StreamView)
    func streamViewDidTapStartReplayButton(_ view: StreamView)
    func streamViewDidTapStopReplayButton(_ view: StreamView)
    func streamViewDidTapConfigureReplayButton(_ view: StreamView)
    func streamViewDidTapReplayFailedButton(_ view: StreamView)
    func streamView(_ view: StreamView, didMoveTimeSlider timeInterval: TimeInterval)
}
