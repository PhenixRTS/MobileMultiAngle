//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Combine
import PhenixClosedCaptions
import PhenixCore
import UIKit

class StreamViewController: UIViewController, Storyboarded {
    // swiftlint:disable:next force_cast
    private var contentView: StreamView { view as! StreamView }
    private var replayStateCancellable: AnyCancellable?
    private var replayHeadCancellable: AnyCancellable?
    private var replayDateCancellable: AnyCancellable?

    var viewModel: ViewModel!
    var collectionViewController: StreamCollectionViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(viewModel != nil, "ViewModel should exist!")
        assert(collectionViewController != nil, "Stream Collection View Controller should exist!")

        contentView.delegate = self
        contentView.setup()
        contentView.replayConfigurationTitle = viewModel.selectedReplayMode.title

        viewModel.getPreviewLayer = { [weak self] in
            self?.contentView.previewLayer
        }

        setupStreamCollectionViewController()

        viewModel.subscribeForClosedCaptions(contentView.closedCaptionsView)
        viewModel.subscribeForChannelListEvents()

        replayStateCancellable = viewModel.selectedChannelReplayStatePublisher.sink { [weak self] state in
            self?.selectedChannelReplayStateDidChange(state)
        }

        replayHeadCancellable = viewModel.selectedChannelReplayHeadPublisher.sink { [weak self] timeInterval in
            self?.selectedChannelReplayHeadDidChange(timeInterval)
        }

        replayDateCancellable = viewModel.selectedChannelReplayDatePublisher.sink { [weak self] dateString in
            self?.contentView.replayTimeTitle = dateString
        }

        viewModel.joinToChannels()
    }

    private func selectedChannelReplayStateDidChange(_ state: PhenixCore.TimeShift.State) {
        let newState: ReplayState

        switch state {
        case .idle, .ended:
            newState = .notReady

        case .starting:
            newState = .loading

        case .ready:
            newState = .ready

        case .playing, .paused:
            newState = .playing

        case .seeking, .seekingSucceeded:
            newState = .seeking

        case .failed:
            newState = .failure
        }

        contentView.setReplay(state: newState)
    }

    private func selectedChannelReplayHeadDidChange(_ timeInterval: TimeInterval) {
        contentView.setSliderValuesIfNeeded(
            timeInterval: timeInterval,
            duration: viewModel.selectedReplayMode.duration
        )
    }

    private func setupStreamCollectionViewController() {
        addChild(collectionViewController)
        contentView.addStreamCollectionView(collectionViewController.view)
        collectionViewController.didMove(toParent: self)
    }

    private func setReplay(_ replay: Replay) {
        contentView.replayConfigurationTitle = replay.title
        viewModel.selectReplayMode(replay)
    }
}

extension StreamViewController {
    enum ReplayState {
        case notReady
        case loading
        case ready
        case playing
        case seeking
        case failure
    }
}

extension StreamViewController: StreamViewDelegate {
    var isClosedCaptionsEnabled: Bool {
        viewModel.isClosedCaptionsEnabled
    }

    func streamViewDidToggleClosedCaptions(_ view: StreamView) {
        viewModel.isClosedCaptionsEnabled.toggle()
    }

    func streamViewDidTapStartReplayButton(_ view: StreamView) {
        viewModel.startReplay()
    }

    func streamViewDidTapStopReplayButton(_ view: StreamView) {
        viewModel.stopReplay()
    }

    func streamViewDidTapReplayFailedButton(_ view: StreamView) {
        // Reload already selected replay.
        viewModel.selectReplayMode(viewModel.selectedReplayMode)
    }

    func streamViewDidTapConfigureReplayButton(_ view: StreamView) {
        let alertController = UIAlertController(title: "Select replay time", message: nil, preferredStyle: .actionSheet)
        for replay in viewModel.replayModes {
            alertController.addAction(UIAlertAction(title: replay.title, style: .default) { [weak self] _ in
                guard let self = self else {
                    return
                }

                self.setReplay(replay)
            })
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }

    func streamView(_ view: StreamView, didMoveTimeSlider timeInterval: TimeInterval) {
        viewModel.moveReplay(offset: timeInterval)
    }
}
