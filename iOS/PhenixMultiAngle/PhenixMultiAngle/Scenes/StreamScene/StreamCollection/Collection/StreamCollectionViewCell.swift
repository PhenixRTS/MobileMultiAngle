//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Combine
import PhenixCore
import UIKit

class StreamCollectionViewCell: UICollectionViewCell {
    private static let offlineBackgroundColor = UIColor(patternImage: UIImage(named: "OfflineNoise")!)

    private lazy var previewView: UIView = {
        let view = UIView()
        return view
    }()

    private lazy var offlineLabel: UILabel = {
        let label = UILabel()
        label.text = "OFFLINE"
        label.font = .boldSystemFont(ofSize: 12)
        label.textColor = .label
        return label
    }()

    private lazy var activityIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.color = .label
        view.startAnimating()
        return view
    }()

    private lazy var selectionLayer: CALayer = {
        let layer = CALayer()
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 3
        layer.cornerRadius = 5
        return layer
    }()

    private var viewModel: ViewModel?

    override init(frame: CGRect) {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ViewModel) {
        self.viewModel = viewModel

        viewModel.getPreviewLayer = { [weak self] in
            self?.previewView.layer
        }
        viewModel.onChannelStateChange = { [weak self] state in
            self?.channelStateDidChange(state)
        }
        viewModel.onChannelSelectionChange = { [weak self] isSelected in
            self?.channelSelectionDidChange(isSelected)
        }

        viewModel.subscribeForEvents()
    }

    // MARK: - Private methods

    private func setup() {
        setupElements()
    }

    private func setupElements() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        offlineLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(previewView)
        addSubview(offlineLabel)
        addSubview(activityIndicatorView)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: topAnchor),
            previewView.bottomAnchor.constraint(equalTo: bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: trailingAnchor),

            offlineLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            offlineLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            activityIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func setSelected(_ isSelected: Bool) {
        if isSelected {
            selectionLayer.frame = layer.bounds
            layer.addSublayer(selectionLayer)
        } else {
            selectionLayer.removeFromSuperlayer()
        }
    }

    // MARK: - Completions

    private func channelStateDidChange(_ state: PhenixCore.Channel.State) {
        let isOffline = state == .offline || state == .noStream

        offlineLabel.isHidden = !isOffline
        activityIndicatorView.isHidden = state != .joining
    }

    private func channelSelectionDidChange(_ isSelected: Bool) {
        setSelected(isSelected)
    }
}
