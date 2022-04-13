//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import PhenixClosedCaptions
import UIKit

class StreamView: UIView {
    typealias ReplayState = StreamViewController.ReplayState

    private static let closedCaptionsEnabledImage = UIImage(named: "cc_enabled")?.withRenderingMode(.alwaysTemplate)
    private static let closedCaptionsDisabledImage = UIImage(named: "cc_disabled")?.withRenderingMode(.alwaysTemplate)

    @IBOutlet private var previewView: UIView!
    @IBOutlet private var streamCollectionContainerView: UIView!
    @IBOutlet private var replayControls: UIStackView!
    @IBOutlet private var startReplayButton: UIButton!
    @IBOutlet private var stopReplayButton: UIButton!
    @IBOutlet private var fetchReplayButton: UIButton!
    @IBOutlet private var configureReplayButton: UIButton!
    @IBOutlet private var replayFailedButton: UIButton!
    @IBOutlet private var replayTimeLabel: UILabel! {
        didSet { replayTimeLabel.text = "" }
    }
    @IBOutlet private var replayTimeSlider: UISlider! {
        didSet {
            replayTimeSlider.isExclusiveTouch = true
            replayTimeSlider.addTarget(self, action: #selector(sliderValueChanged(_:event:)), for: .valueChanged)
        }
    }
    @IBOutlet private var replayTimeSliderViewContainers: [UIView]!
    @IBOutlet private var closedCaptionsToggleButton: UIButton! {
        didSet { reloadClosedCaptionsButtonImage() }
    }
    @IBOutlet private(set) var closedCaptionsView: PhenixClosedCaptionsView!

    private var userControlsSlider: Bool = false

    weak var delegate: StreamViewDelegate?

    var previewLayer: CALayer {
        previewView.layer
    }

    var replayTimeTitle: String {
        get { replayTimeLabel.text ?? "" }
        set { replayTimeLabel.text = newValue }
    }

    var replayConfigurationTitle: String {
        get { configureReplayButton.title(for: .normal) ?? "" }
        set { configureReplayButton.setTitle(newValue, for: .normal) }
    }

    func setup() {
        setupElements()
        reloadClosedCaptionsButtonImage()
    }

    func setReplay(state: ReplayState) {
        setControlVisibility(replayState: state)
        setControlInteraction(replayState: state)
    }

    func setSliderValuesIfNeeded(timeInterval: TimeInterval, duration: TimeInterval) {
        guard userControlsSlider == false else {
            return
        }

        setSliderValues(minimum: 0, current: Float(timeInterval), maximum: Float(duration))
    }

    func addStreamCollectionView(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        streamCollectionContainerView.addSubview(view)

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: streamCollectionContainerView.topAnchor),
            view.leadingAnchor.constraint(equalTo: streamCollectionContainerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: streamCollectionContainerView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: streamCollectionContainerView.bottomAnchor)
        ])
    }

    // MARK: - Private methods

    private func setupElements() {
        [startReplayButton, stopReplayButton, fetchReplayButton, replayFailedButton, configureReplayButton]
            .forEach { $0.withBorderColor(.black) }

        setReplay(state: .loading)
    }

    private func setSliderValues(minimum: Float = 0, current: Float, maximum: Float) {
        replayTimeSlider.minimumValue = minimum
        replayTimeSlider.maximumValue = maximum
        replayTimeSlider.setValue(current, animated: true)
    }

    @IBAction private func startReplayButtonTapped(_ sender: UIButton) {
        delegate?.streamViewDidTapStartReplayButton(self)
    }

    @IBAction private func configureReplayButtonTapped(_ sender: UIButton) {
        delegate?.streamViewDidTapConfigureReplayButton(self)
    }

    @IBAction private func stopReplayButtonTapped(_ sender: UIButton) {
        delegate?.streamViewDidTapStopReplayButton(self)
    }

    @IBAction private func closedCaptionsToggleButtonTapped(_ sender: Any) {
        delegate?.streamViewDidToggleClosedCaptions(self)
        reloadClosedCaptionsButtonImage()
    }

    @IBAction private func replayFailedButtonTapped(_ sender: UIButton) {
        delegate?.streamViewDidTapReplayFailedButton(self)
    }

    @objc private func sliderValueChanged(_ slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                userControlsSlider = true
            case .ended:
                userControlsSlider = false
                delegate?.streamView(self, didMoveTimeSlider: TimeInterval(slider.value))
            default:
                break
            }
        }
    }

    private func reloadClosedCaptionsButtonImage() {
        let isClosedCaptionsEnabled = delegate?.isClosedCaptionsEnabled ?? false
        let image = isClosedCaptionsEnabled ? Self.closedCaptionsEnabledImage : Self.closedCaptionsDisabledImage
        closedCaptionsToggleButton.setImage(image, for: .normal)
    }

    private func setControlVisibility(replayState state: ReplayState) {
        let inReplayMode = state == .playing || state == .seeking

        closedCaptionsView.isHidden = inReplayMode
        closedCaptionsToggleButton.isHidden = inReplayMode

        stopReplayButton.isHidden = !inReplayMode
        startReplayButton.isHidden = state != .ready
        configureReplayButton.isHidden = state != .ready && state != .failure

        fetchReplayButton.isHidden = state != .loading
        replayFailedButton.isHidden = state != .failure

        replayTimeSliderViewContainers.forEach { $0.isHidden = !inReplayMode }
    }

    private func setControlInteraction(replayState state: ReplayState) {
        let isStartReplayButtonEnabled = state == .ready
        startReplayButton.isEnabled = isStartReplayButtonEnabled
        startReplayButton.backgroundColor = isStartReplayButtonEnabled ? .green : .gray

        let isStopReplayButtonEnabled = state == .playing
        stopReplayButton.isEnabled = isStopReplayButtonEnabled
        stopReplayButton.backgroundColor = isStopReplayButtonEnabled ? .green : .gray

        let isConfigureReplayButtonEnabled = state == .ready || state == .failure
        configureReplayButton.isEnabled = isConfigureReplayButtonEnabled
        configureReplayButton.alpha = isConfigureReplayButtonEnabled ? 1 : 0.5
    }
}

private extension UIButton {
    @discardableResult
    func withBorderColor(_ color: UIColor) -> Self {
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = color.withAlphaComponent(0.25).cgColor
        return self
    }
}
