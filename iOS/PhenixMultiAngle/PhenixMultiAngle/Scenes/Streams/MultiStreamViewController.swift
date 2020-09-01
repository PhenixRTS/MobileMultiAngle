//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixCore
import UIKit

class MultiStreamViewController: UIViewController, Storyboarded {
    var phenixManager: PhenixChannelJoining!
    var channels: [Channel] = []

    private var collectionViewManager: MultiStreamPreviewCollectionViewManager!
    private var selectedChannelIndexPath: IndexPath? {
        didSet {
            let indexPaths = [oldValue, selectedChannelIndexPath].compactMap { $0 }
            multiStreamView.reloadItems(at: indexPaths)
        }
    }
    
    var multiStreamView: MultiStreamView {
        view as! MultiStreamView
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        multiStreamView.invalidateLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(phenixManager != nil, "Phenix Manager is required")

        collectionViewManager = MultiStreamPreviewCollectionViewManager()
        collectionViewManager.channels = channels
        collectionViewManager.isMemberIndexPathSelected = { [weak self] indexPath in
            self?.selectedChannelIndexPath == indexPath
        }
        collectionViewManager.itemSelectionHandler = { [weak self] selectedIndexPath in
            self?.select(channelAt: selectedIndexPath)
        }

        multiStreamView.configurePreviewCollectionView(with: collectionViewManager)

        for channel in channels {
            join(channel)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateChannelSelection()
    }
}

private extension MultiStreamViewController {
    func join(_ channel: Channel) {
        phenixManager.join(channel)
    }

    func select(channelAt indexPath: IndexPath) {
        guard indexPath != selectedChannelIndexPath else {
            return
        }

        let channel = collectionViewManager.channels[indexPath.item]
        os_log(.debug, log: .ui, "Select channel: %{PRIVATE}s", channel.description)

        selectedChannelIndexPath = indexPath
        channel.addPrimaryLayer(to: multiStreamView.previewLayer)
    }

    /// Sets selected layer on the currently selected channel or the first channel in the channel list
    func updateChannelSelection() {
        if let indexPath = self.selectedChannelIndexPath {
            self.select(channelAt: indexPath)
        } else if collectionViewManager.channels.isEmpty == false {
            self.select(channelAt: IndexPath(item: 0, section: 0))
        }
    }
}
