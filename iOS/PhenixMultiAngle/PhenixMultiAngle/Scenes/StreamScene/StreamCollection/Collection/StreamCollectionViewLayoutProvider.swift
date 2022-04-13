//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import UIKit

struct StreamCollectionViewLayoutProvider {
    let interSectionSpacing: CGFloat = 16

    func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = interSectionSpacing

        let provider: UICollectionViewCompositionalLayoutSectionProvider = { (_, _) -> NSCollectionLayoutSection in
            makeSection()
        }

        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: provider,
            configuration: configuration
        )

        return layout
    }

    private func makeSection() -> NSCollectionLayoutSection {
        let itemLayoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalHeight(1)
        )

        let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

        let groupLayoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(0.5)
        )

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupLayoutSize, subitems: [item])
        group.interItemSpacing = .fixed(0)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .zero
        section.interGroupSpacing = 0

        return section
    }
}
