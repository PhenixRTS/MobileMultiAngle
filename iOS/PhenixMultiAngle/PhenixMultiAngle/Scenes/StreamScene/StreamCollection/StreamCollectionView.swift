//
//  Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import UIKit

class StreamCollectionView: UIView {
    private(set) lazy var collectionView: UICollectionView = {
        let layoutProvider = StreamCollectionViewLayoutProvider()
        let layout = layoutProvider.makeLayout()

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.bounces = false
        view.delegate = self
        view.allowsSelection = true
        view.backgroundColor = .systemBackground
        view.delaysContentTouches = false
        view.allowsMultipleSelection = false

        return view
    }()

    weak var delegate: StreamCollectionViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        setupElements()
    }

    private func setupElements() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

extension StreamCollectionView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.streamCollectionView(self, didSelectItemAt: indexPath)
    }
}
