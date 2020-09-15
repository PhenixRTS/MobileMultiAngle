//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import UIKit

/// Closed Caption view
///
/// Closed Caption view contains a black background with a white caption text on it by default.
/// Caption text supports Dynamic Type for automatic size changes.
///
/// After adding PhenixClosedCaptionView as a subview to another UIView, NSLayoutConstraints will be
/// added automatically to position PhenixClosedCaptionView centred horizontally, near the bottom of its superview.
public final class PhenixClosedCaptionView: UIView {
    private var captionLabel = UILabel.makeCaption()

    /// Displayed caption text
    public var caption: String? {
        get { captionLabel.text }
        set { captionLabel.text = newValue }
    }

    /// Caption text color
    public var textColor: UIColor {
        get { captionLabel.textColor }
        set { captionLabel.textColor = newValue }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        addSuperviewConstraints()
    }
}

private extension PhenixClosedCaptionView {
    func setup() {
        backgroundColor = .black
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(captionLabel)

        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: topAnchor, constant: directionalLayoutMargins.top),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: directionalLayoutMargins.leading),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -directionalLayoutMargins.trailing),
            captionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -directionalLayoutMargins.bottom)
        ])
    }

    /// Add NSLayoutConstraints to position this view in the superview if superview exists
    func addSuperviewConstraints() {
        guard let superview = superview else {
            return
        }

        let constraints = [
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -16),
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            widthAnchor.constraint(lessThanOrEqualTo: superview.widthAnchor, multiplier: 0.9)
        ]

        NSLayoutConstraint.activate(constraints)
    }
}

fileprivate extension UILabel {
    static func makeCaption() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 3
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        return label
    }
}
