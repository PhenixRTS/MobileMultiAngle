//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import UIKit

class MultiStreamView: UIView {
    @IBOutlet private var primaryPreview: UIView!
    @IBOutlet private var secondaryPreviewCollectionView: UICollectionView!
    
    var previewLayer: CALayer {
        primaryPreview.layer
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
}


