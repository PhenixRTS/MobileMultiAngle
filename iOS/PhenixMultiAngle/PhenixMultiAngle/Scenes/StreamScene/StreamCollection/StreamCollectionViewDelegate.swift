//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation

protocol StreamCollectionViewDelegate: AnyObject {
    func streamCollectionView(_ view: StreamCollectionView, didSelectItemAt indexPath: IndexPath)
}
