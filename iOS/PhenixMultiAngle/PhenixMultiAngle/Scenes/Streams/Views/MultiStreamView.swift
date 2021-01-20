//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import PhenixClosedCaptions
import UIKit

protocol MultiStreamViewDelegate: AnyObject {
    var isClosedCaptionsEnabled: Bool { get set }

    func replayModeDidChange(_ inReplayMode: Bool)
    func replayConfigurationButtonTapped()
    func replayTimeSliderDidMove(_ time: TimeInterval)
    func restartReplayConfiguration()
}

class MultiStreamView: UIView {
    typealias State = MultiStreamReplayController.State

    @IBOutlet private var primaryPreview: UIView!
    @IBOutlet private var primaryPreviewOverlayView: UIView!
    @IBOutlet private var secondaryPreviewCollectionView: UICollectionView!
    @IBOutlet private var replayControls: UIStackView!
    @IBOutlet private var replayButton: UIButton!
    @IBOutlet private var replayConfigurationButton: UIButton!
    @IBOutlet private var goLiveButton: UIButton!
    @IBOutlet private var fetchingReplayButton: UIButton!
    @IBOutlet private var replayFailedButton: UIButton!
    @IBOutlet private var slider: UISlider!
    @IBOutlet private var timerLabel: UILabel!
    @IBOutlet private var replaySliderViewContainers: [UIView]!
    @IBOutlet private(set) var closedCaptionsView: PhenixClosedCaptionsView!
    @IBOutlet private var closedCaptionsButton: UIButton!

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        return formatter
    }()

    private var userControlsSlider: Bool = false

    weak var delegate: MultiStreamViewDelegate?

    var previewLayer: CALayer {
        primaryPreview.layer
    }

    var replayConfigurationTitle: String? {
        replayConfigurationButton.title(for: .normal)
    }

    func configureUIElements() {
        let buttons: [UIButton] = [replayButton, goLiveButton, replayConfigurationButton, replayFailedButton, fetchingReplayButton]

        buttons.forEach { button in
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.black.withAlphaComponent(0.25).cgColor
        }
        
        slider.isExclusiveTouch = true
        slider.addTarget(self, action: #selector(sliderValueChanged(_:event:)), for: .valueChanged)

        timerLabel.text = ""

        replay(state: .loading)
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

    func replay(state: State) {
        setControlVisibility(forReplay: state)
        setControlInteraction(forReplay: state)
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
    private func closedCaptionsButtonTapped(_ sender: Any) {
        delegate?.isClosedCaptionsEnabled.toggle()
        if delegate?.isClosedCaptionsEnabled == true {
            closedCaptionsButton.setImage(UIImage(named: "cc_enabled"), for: .normal)
        } else {
            closedCaptionsButton.setImage(UIImage(named: "cc_disabled"), for: .normal)
        }
    }

    @IBAction
    private func replayFailedButtonTapped(_ sender: UIButton) {
        delegate?.restartReplayConfiguration()
    }

    @objc
    private func sliderValueChanged(_ slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                userControlsSlider = true
            case .ended:
                userControlsSlider = false
                delegate?.replayTimeSliderDidMove(TimeInterval(slider.value))
            default:
                break
            }
        }
    }
}

private extension MultiStreamView {
    func setControlVisibility(forReplay state: State) {
        let inReplayMode = state == .playing || state == .seeking

        closedCaptionsButton.isHidden = inReplayMode
        closedCaptionsView.isHidden = inReplayMode

        replayButton.isHidden = state != .readyToPlay
        replayConfigurationButton.isHidden = state != .readyToPlay && state != .failure
        goLiveButton.isHidden = !inReplayMode

        fetchingReplayButton.isHidden = state != .loading
        replayFailedButton.isHidden = state != .failure

        replaySliderViewContainers.forEach { $0.isHidden = !inReplayMode }
    }

    func setControlInteraction(forReplay state: State) {
        let isReplayButtonEnabled = state == .readyToPlay
        replayButton.isEnabled = isReplayButtonEnabled
        replayButton.backgroundColor = isReplayButtonEnabled ? UIColor.green : UIColor.gray

        let isGoLiveButtonEnabled = state == .playing
        goLiveButton.isEnabled = isGoLiveButtonEnabled
        goLiveButton.backgroundColor = isGoLiveButtonEnabled ? UIColor.green : UIColor.gray

        let isReplayConfigurationButtonEnabled = state == .readyToPlay || state == .failure
        replayConfigurationButton.isEnabled = isReplayConfigurationButtonEnabled
        replayConfigurationButton.alpha = isReplayConfigurationButtonEnabled ? 1 : 0.5
    }

    func setSliderPosition(startDate: Date, currentDate: Date, endDate: Date) {
        guard userControlsSlider == false else { return }
        let max = endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        let current = currentDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        slider.minimumValue = 0
        slider.maximumValue = Float(max)
        slider.setValue(Float(current), animated: true)
    }
}
