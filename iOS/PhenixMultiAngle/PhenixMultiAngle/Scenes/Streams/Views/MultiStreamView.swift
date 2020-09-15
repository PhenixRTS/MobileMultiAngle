//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import PhenixClosedCaptions
import UIKit

protocol MultiStreamViewDelegate: AnyObject {
    func replayModeDidChange(_ inReplayMode: Bool)
    func replayConfigurationButtonTapped()
    func replayTimeSliderDidMove(_ time: TimeInterval)
}

class MultiStreamView: UIView {
    typealias ReplayState = MultiStreamViewController.ReplayState

    @IBOutlet private var primaryPreview: UIView!
    @IBOutlet private var primaryPreviewOverlayView: UIView!
    @IBOutlet private var secondaryPreviewCollectionView: UICollectionView!
    @IBOutlet private var replayControls: UIStackView!
    @IBOutlet private var replayButton: UIButton!
    @IBOutlet private var replayConfigurationButton: UIButton!
    @IBOutlet private var goLiveButton: UIButton!
    @IBOutlet private var slider: UISlider!
    @IBOutlet private var timerLabel: UILabel!
    @IBOutlet private var replaySliderViewContainers: [UIView]!
    private var closedCaptionView: PhenixClosedCaptionView!

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        return formatter
    }()

    weak var delegate: MultiStreamViewDelegate?

    var previewLayer: CALayer {
        primaryPreview.layer
    }

    var replayConfigurationTitle: String? {
        replayConfigurationButton.title(for: .normal)
    }

    func configureUIElements() {
        replayButton.layer.cornerRadius = 10
        goLiveButton.layer.cornerRadius = 10
        replayConfigurationButton.layer.cornerRadius = 10
        slider.isExclusiveTouch = true

        timerLabel.text = ""

        // Create Closed Captions view
        closedCaptionView = PhenixClosedCaptionView()
        primaryPreviewOverlayView.addSubview(closedCaptionView)

        replay(state: .notReady)
    }

    func configurePreviewCollectionView(with manager: MultiStreamPreviewCollectionViewManager) {
        secondaryPreviewCollectionView.delegate = manager
        secondaryPreviewCollectionView.dataSource = manager
        secondaryPreviewCollectionView.delaysContentTouches = false
        secondaryPreviewCollectionView.allowsSelection = true
        secondaryPreviewCollectionView.allowsMultipleSelection = false
        secondaryPreviewCollectionView.collectionViewLayout = UICollectionViewFlowLayout()
    }

    func invalidateLayout() {
        secondaryPreviewCollectionView.collectionViewLayout.invalidateLayout()
    }

    func reloadItems() {
        secondaryPreviewCollectionView.reloadData()
    }

    func reloadItems(at indexPaths: [IndexPath]) {
        secondaryPreviewCollectionView.reloadItems(at: indexPaths)
    }

    func setReplayConfigurationButtonTitle(_ title: String) {
        replayConfigurationButton.setTitle(title, for: .normal)
    }

    func setReplayPlaybackHeadDate(startDate: Date, currentDate: Date, endDate: Date) {
        timerLabel.text = dateFormatter.string(from: currentDate)
        setSliderPosition(startDate: startDate, currentDate: currentDate, endDate: endDate)
    }

    func setCaption(_ caption: String?) {
        closedCaptionView.caption = caption
    }

    func replay(state: ReplayState) {
        setControlVisibility(forReplay: state)
        setControlInteraction(forReplay: state)
    }

    func updateVisibilityForClosedCaptions(forReplay state: ReplayState) {
        let inReplayMode = state == .active || state == .waitingForPlayback

        closedCaptionView.isHidden = inReplayMode || closedCaptionView?.caption?.isEmpty != false
    }

    @IBAction
    private func replayButtonTapped(_ sender: UIButton) {
        delegate?.replayModeDidChange(true)
    }

    @IBAction
    private func replayTimeButtonTapped(_ sender: UIButton) {
        delegate?.replayConfigurationButtonTapped()
    }

    @IBAction
    private func goLiveButtonTapped(_ sender: UIButton) {
        delegate?.replayModeDidChange(false)
    }

    @IBAction
    private func sliderDidMove(_ sender: UISlider) {
        delegate?.replayTimeSliderDidMove(TimeInterval(sender.value))
    }
}

private extension MultiStreamView {
    func setControlVisibility(forReplay state: ReplayState) {
        let inReplayMode = state == .active || state == .waitingForPlayback

        updateVisibilityForClosedCaptions(forReplay: state)
        replayButton.isHidden = inReplayMode
        goLiveButton.isHidden = !inReplayMode
        replayConfigurationButton.isHidden = inReplayMode
        replaySliderViewContainers.forEach { $0.isHidden = !inReplayMode }
    }

    func setControlInteraction(forReplay state: ReplayState) {
        replayButton.isEnabled = state == .ready
        replayButton.backgroundColor = state == .ready ? UIColor.green : UIColor.white
        replayButton.alpha = state == .ready ? 1 : 0.5

        goLiveButton.isEnabled = state == .active
        goLiveButton.backgroundColor = state == .active ? UIColor.green : UIColor.white
        goLiveButton.alpha = state == .active ? 1 : 0.5

        replayConfigurationButton.isEnabled = state == .ready
        replayConfigurationButton.alpha = state == .ready ? 1 : 0.5
    }

    func setSliderPosition(startDate: Date, currentDate: Date, endDate: Date) {
        let max = endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        let current = currentDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        slider.minimumValue = 0
        slider.maximumValue = Float(max)
        slider.setValue(Float(current), animated: true)
    }
}
