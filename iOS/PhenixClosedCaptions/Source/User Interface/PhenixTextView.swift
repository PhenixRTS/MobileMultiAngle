//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import UIKit

/// Closed Caption Text view
///
/// Closed Caption view contains a black background with a white caption text on it by default.
/// Caption text supports Dynamic Type for automatic size changes.
internal final class PhenixTextView: UIView {
    internal static var font: UIFont = {
        if #available(iOS 13.0, *) {
            return UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        } else {
            return .preferredFont(forTextStyle: .caption1)
        }
    }()

    private var captionLabel = UILabel.makeCaption()
    private var _backgroundColor: UIColor = .clear

    internal var captionAttributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = justify.nsTextAlignment
        style.lineBreakMode = wordWrap ? .byWordWrapping : .byTruncatingTail

        return [
            .font: Self.font,
            .foregroundColor: textColor,
            .backgroundColor: _backgroundColor,
            .paragraphStyle: style
        ]
    }

    /// Displayed caption text
    internal var caption: String {
        get { captionLabel.attributedText?.string ?? "" }
        set { setAttributedText(newValue ?? "") }
    }

    internal override var backgroundColor: UIColor? {
        get { _backgroundColor }
        set { _backgroundColor = (newValue ?? .clear).withAlphaComponent(backgroundAlpha) }
    }

    internal var backgroundAlpha: CGFloat = 1.0 {
        didSet { _backgroundColor = _backgroundColor.withAlphaComponent(backgroundAlpha) }
    }

    internal var justify: PhenixWindowUpdate.Justification = .center
    internal var textColor: UIColor = .white
    internal var wordWrap: Bool = true
    internal var zOrder: Int = 0 {
        didSet { layer.zPosition = CGFloat(zOrder) }
    }

    internal override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    internal required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    internal func reloadCaptionStyle() {
        setAttributedText(caption)
    }
}

private extension PhenixTextView {
    func setup() {
        isOpaque = false

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionLabel)

        setInnerElementConstraints()
    }

    func setInnerElementConstraints() {
        let constraints: [NSLayoutConstraint] = [
            captionLabel.topAnchor.constraint(equalTo: topAnchor),
            captionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            captionLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
    }

    func setAttributedText(_ text: String) {
        captionLabel.attributedText = NSAttributedString(string: text, attributes: captionAttributes)
    }
}

fileprivate extension UILabel {
    static func makeCaption() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = PhenixTextView.font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        return label
    }
}
