//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixCore
import UIKit

class MultiStreamPreviewCollectionViewCell: UICollectionViewCell {
    private lazy var activityIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.startAnimating()
        if #available(iOS 13.0, *) {
            view.color = .label
        } else {
            view.color = .black
        }
        return view
    }()

    private lazy var offlineLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "OFFLINE"
        if #available(iOS 13.0, *) {
            label.textColor = .label
        } else {
            label.textColor = .black
        }
        label.font = .boldSystemFont(ofSize: 12)
        return label
    }()

    var isActivityIndicatorVisible: Bool = false {
        didSet {
            if isActivityIndicatorVisible && isOfflineLabelVisible == false {
                add(activityIndicatorView)
            } else {
                remove(activityIndicatorView)
            }
        }
    }

    var isOfflineLabelVisible: Bool = false {
        didSet {
            if isOfflineLabelVisible {
                add(offlineLabel)
            } else {
                remove(offlineLabel)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }


    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // When the cell will be prepared for the reuse, we need to remove all the preview layers so that there would not be a situation that other (previous) member video stream would flicker before showing correct video stream.
        contentView.layer.sublayers?
            .filter { $0.name == VideoLayer.previewLayerName }
            .forEach { layer in
                os_log(.debug, log: .ui, "Removing layer: %{PRIVATE}s", layer.description)
                layer.removeFromSuperlayer()
            }
    }
}

private extension MultiStreamPreviewCollectionViewCell {
    func setup() {
        contentView.layer.cornerRadius = 5
    }

    func add(_ view: UIView) {
        contentView.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func remove(_ view: UIView) {
        view.removeFromSuperview()
    }
}

extension MultiStreamPreviewCollectionViewCell: ChannelStreamObserver {
    func channelStreamStateDidChange(_ channel: Channel, state: Channel.StreamState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            switch state {
            case .playing:
                self.isActivityIndicatorVisible = false
            case .noStreamPlaying:
                self.isActivityIndicatorVisible = true
            case .failure:
                fatalError("Stream couldn't be played for the channel, \(channel)")
            }
        }
    }
}

extension MultiStreamPreviewCollectionViewCell: ChannelJoinObserver {
    func channelJoinStateDidChange(_ channel: Channel, state: Channel.JoinState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            switch state {
            case .joined:
                self.isOfflineLabelVisible = false

                if channel.streamState == .noStreamPlaying {
                    self.isActivityIndicatorVisible = true
                }
            case .pending,
                 .notJoined:
                self.isOfflineLabelVisible = true
            case .failure:
                fatalError("Could not establish the connection to the channel, \(channel)")
            }
        }
    }
}
