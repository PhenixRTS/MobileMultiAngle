//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import PhenixCore
import UIKit

class MultiStreamPreviewCollectionViewManager: NSObject {
    /// Contains references to the shown secondary previews
    ///
    /// There should only be one secondary preview visible on the screen, so all of the previews can be easily removed by cleaning this Set.
    private var secondaryPreviewLayers: Set<CALayer> = []
    /// Selected item indicator KVO for the layer frame updates
    private var selectionLayerObservation: NSKeyValueObservation?
    /// Selected item indicator
    private lazy var selectionLayer: CALayer = {
        let layer = CALayer()
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 3
        layer.cornerRadius = 5
        return layer
    }()

    var channels: [Channel] = []
    var isMemberIndexPathSelected: ((IndexPath) -> Bool)?
    var itemSelectionHandler: ((IndexPath) -> Void)?
    var limitBandwidth: ((Channel) -> Void)?

    deinit {
        selectionLayerObservation = nil
    }
}

private extension MultiStreamPreviewCollectionViewManager {
    func markCellSelected(_ cell: UICollectionViewCell) {
        selectionLayer.frame = cell.layer.bounds
        cell.layer.addSublayer(selectionLayer)

        selectionLayerObservation?.invalidate()
        selectionLayerObservation = cell.layer.observe(\.bounds, options: [.new]) { [weak self] _, change in
            self?.selectionLayer.frame = change.newValue ?? .zero
        }
    }
}

extension MultiStreamPreviewCollectionViewManager: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        channels.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! MultiStreamPreviewCollectionViewCell

        let channel = channels[indexPath.item]

        // If current cell index path is selected, then it means that this member stream is showed in primary preview,
        // we need to add the secondary preview layer to this cell's layer
        if isMemberIndexPathSelected?(indexPath) == true {
            // Clear all previously added secondary preview layers (there should be only one secondary layer visible)
            // When we need to show a member secondary preview layer, we need to be sure that any other secondary preview layers are not visible.
            // There is no need to waste performance on rendering stream if these layers are not visible.
            secondaryPreviewLayers.forEach { $0.removeFromSuperlayer() }
            secondaryPreviewLayers.removeAll()

            channel.addSecondaryLayer(to: cell.contentView.layer)
            channel.media?.setAudio(enabled: true)

            // Save the secondary preview layer inside the preview array
            secondaryPreviewLayers.insert(channel.secondaryPreviewLayer)

            markCellSelected(cell)
        } else {
            channel.addPrimaryLayer(to: cell.contentView.layer)
            channel.media?.setAudio(enabled: false)
            limitBandwidth?(channel)
        }

        switch (channel.joinState, channel.streamState) {
        case (.joined, .playing):
            cell.state = .ready
        case (.joined, .noStreamPlaying):
            cell.state = .pending
        default:
            cell.state = .notReady
        }

        channel.addStreamObserver(cell)
        channel.addJoinObserver(cell)

        return cell
    }
}

extension MultiStreamPreviewCollectionViewManager: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if UIApplication.shared.statusBarOrientation.isPortrait {
            let width: CGFloat = (collectionView.bounds.size.width - 15) / 2
            return CGSize(width: width, height: 100)
        } else {
            let width: CGFloat = collectionView.bounds.size.width - 10
            return CGSize(width: width, height: 100)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if UIApplication.shared.statusBarOrientation.isPortrait {
            return UIEdgeInsets(top: 5, left: 5, bottom: 0, right: 5)
        } else {
            return UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        itemSelectionHandler?(indexPath)
    }
}
