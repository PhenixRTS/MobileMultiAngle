//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import PhenixCore
import UIKit

class MultiStreamPreviewCollectionViewManager: NSObject, UICollectionViewDataSource {
    var members: [RoomMember] = []
    var isMemberIndexPathSelected: ((IndexPath) -> Bool)?
    var secondaryPreviewLayers: Set<CALayer> = []

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        members.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! MultiStreamPreviewCollectionViewCell

        let member = members[indexPath.item]

        // If current cell index path is selected, then it means that this member stream is showed in primary preview,
        // we need to add to this layer the secondary preview layer
        if isMemberIndexPathSelected?(indexPath) == true {
            secondaryPreviewLayers.forEach { $0.removeFromSuperlayer() }
            secondaryPreviewLayers.removeAll()

            member.addSecondaryLayer(to: cell.layer)
            
            secondaryPreviewLayers.insert(member.secondaryPreviewLayer)
        } else {
            member.addPrimaryLayer(to: cell.layer)
        }

        return cell
    }
}
