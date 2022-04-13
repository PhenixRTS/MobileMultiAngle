//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import PhenixCore
import UIKit

extension StreamCollectionViewController {
    class DataSource {
        // swiftlint:disable:next nesting
        typealias DataType = PhenixCore.Channel
        // swiftlint:disable:next nesting
        private typealias DiffableDataSource = UICollectionViewDiffableDataSource<Section, DataType>

        private static let reuseIdentifier = "ChannelCell"

        private let core: PhenixCore

        private var collectionView: UICollectionView?
        private var dataSource: DiffableDataSource?

        init(core: PhenixCore) {
            self.core = core
        }

        func channel(for indexPath: IndexPath) -> PhenixCore.Channel? {
            dataSource?.itemIdentifier(for: indexPath)
        }

        func setCollectionView(_ collectionView: UICollectionView) {
            self.collectionView = collectionView
            registerCells()
            registerDataSource()
        }

        func updateData(_ data: [DataType]) {
            var snapshot = NSDiffableDataSourceSnapshot<Section, DataType>()

            snapshot.appendSections(Section.allCases)
            snapshot.appendItems(data, toSection: .all)

            dataSource?.apply(snapshot)
        }

        private func registerCells() {
            collectionView?.register(StreamCollectionViewCell.self, forCellWithReuseIdentifier: Self.reuseIdentifier)
        }

        private func registerDataSource() {
            guard let collectionView = collectionView else {
                fatalError("UICollectionView must be provided before creating its data source.")
            }

            dataSource = makeDataSource(for: collectionView)
            collectionView.dataSource = dataSource
        }

        private func makeDataSource(for collectionView: UICollectionView) -> DiffableDataSource {
            // swiftlint:disable:next line_length
            UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, channel in
                guard let self = self else {
                    fatalError("Something went wrong.")
                }

                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: Self.reuseIdentifier,
                    for: indexPath
                ) as? StreamCollectionViewCell else {
                    fatalError("Could not load StreamCollectionViewCell")
                }

                let viewModel = StreamCollectionViewCell.ViewModel(core: self.core, channel: channel)
                cell.configure(viewModel: viewModel)

                return cell
            }
        }
    }
}

private extension StreamCollectionViewController.DataSource {
    enum Section: CaseIterable {
        case all
    }
}
