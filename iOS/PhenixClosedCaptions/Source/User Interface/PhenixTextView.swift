//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import UIKit

/// Closed Caption Text view
///
/// Closed Caption view contains a black background with a white caption text on it by default.
/// Caption text supports Dynamic Type for automatic size changes.
internal final class PhenixTextView: UIView {
    private var captionLabel = UILabel.makeCaption()
    private var backgroundView = UIView.makeBackground()

    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    private var horizontalPositionConstraint: NSLayoutConstraint?
    private var verticalPositionConstraint: NSLayoutConstraint?

    internal var textPadding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

    /// Closed Caption window relative anchor point to top-left corner
    ///
    /// `(x: 0.5, y: 0.5)` - center of the view,
    ///
    /// `(x: 1.0, y: 1.0)` - bottom-right corner
    ///
    /// - Important:
    /// After changing this parameter you must call `setNeedsUpdateConstraints()` to update constraints
    internal var relativeAnchorPoint: CGPoint = .init(x: 0.0, y: 0.0)

    /// Closed Caption window relative position inside the Closed Caption window container view
    ///
    /// `(x: 0.0, y: 0.0)` - top-left corner,
    ///
    /// `(x: 0.5, y: 0.5)` - center of the view,
    ///
    /// `(x: 0.5, y: 1.0)` - bottom-center of the view
    ///
    /// - Important:
    /// After changing this parameter you must call `setNeedsUpdateConstraints()` to update constraints
    internal var relativePositionInSuperview: CGPoint = .init(x: 0.5, y: 0.9)

    internal var widthInCharacters: Int = 32

    internal var heightInTextLines: Int = 1

    /// Displayed caption text
    internal var caption: String? {
        get { captionLabel.text }
        set { captionLabel.text = newValue }
    }

    internal override var backgroundColor: UIColor? {
        get { backgroundView.backgroundColor }
        set { backgroundView.backgroundColor = newValue }
    }

    internal var backgroundAlpha: CGFloat {
        get { backgroundView.alpha }
        set { backgroundView.alpha = newValue }
    }

    internal var justify: PhenixWindowUpdate.Justification {
        get { captionLabel.textAlignment.justification }
        set { captionLabel.textAlignment = newValue.nsTextAlignment }
    }

    /// Caption text color
    internal var textColor: UIColor {
        get { captionLabel.textColor }
        set { captionLabel.textColor = newValue }
    }

    internal var wordWrap: Bool {
        get { captionLabel.lineBreakMode == .byWordWrapping }
        set {
            captionLabel.lineBreakMode = newValue ? .byWordWrapping : .byTruncatingTail
            heightConstraint.isActive = newValue == false
        }
    }

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

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setSuperviewPositionConstraints()
    }

    override func updateConstraints() {
        updateFrameConstraints()
        updateSuperviewPositionConstraints()
        super.updateConstraints()
    }
}

private extension PhenixTextView {
    func setup() {
        isOpaque = false

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        addSubview(captionLabel)

        setInnerElementConstraints()
        setFrameConstraints()
    }

    func setInnerElementConstraints() {
        let constraints = [
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            captionLabel.topAnchor.constraint(equalTo: topAnchor, constant: textPadding.top),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textPadding.left),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -textPadding.right),
            captionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -textPadding.bottom),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    func setFrameConstraints() {
        widthConstraint = captionLabel.widthAnchor.constraint(equalToConstant: 0)
        heightConstraint = captionLabel.heightAnchor.constraint(equalToConstant: 0)

        updateFrameConstraints()

        NSLayoutConstraint.activate([widthConstraint, heightConstraint])
    }

    func updateFrameConstraints() {
        let size = calculatePossibleFrameSize(forCharacterCountInLine: widthInCharacters, lineCount: heightInTextLines, font: captionLabel.font)

        widthConstraint?.constant = size.width
        heightConstraint?.constant = size.height + CGFloat(heightInTextLines) // Add additional heightInTextLines count because UILabels and other text representation views add small amount of inset inside the text view.
    }

    func setSuperviewPositionConstraints() {
        guard let superview = superview else {
            return
        }

        // Remove previously set constraints
        NSLayoutConstraint.deactivate([horizontalPositionConstraint, verticalPositionConstraint].compactMap { $0 })

        // Add position constraints
        let horizontal = centerXAnchor.constraint(equalTo: superview.centerXAnchor)
        horizontal.priority = .defaultHigh // Border constrains must be priority.

        let vertical = centerYAnchor.constraint(equalTo: superview.centerYAnchor)
        vertical.priority = .defaultHigh // Border constrains must be priority.

        // Set constraints
        horizontalPositionConstraint = horizontal
        verticalPositionConstraint = vertical

        // Calculate specific anchor point to which position the view in superview
        updateSuperviewPositionConstraints()

        NSLayoutConstraint.activate([horizontal, vertical])
    }

    func updateSuperviewPositionConstraints() {
        guard let superview = superview else {
            return
        }

        assert(0.0...1.0 ~= relativeAnchorPoint.x)
        assert(0.0...1.0 ~= relativeAnchorPoint.y)
        assert(0.0...1.0 ~= relativePositionInSuperview.x)
        assert(0.0...1.0 ~= relativePositionInSuperview.y)

        // Calculate modified position of the window from its superview center position
        let calculatedXPosition = (0.5 - relativePositionInSuperview.x) * -1 * superview.bounds.width
        let calculatedYPosition = (0.5 - relativePositionInSuperview.y) * -1 * superview.bounds.height

        // Calculate modified anchor point inside this view against which it will be positioned
        let calculatedXAnchorPoint = (0.5 - relativeAnchorPoint.x) * CGFloat((widthConstraint?.constant ?? 0) + textPadding.left + textPadding.right)
        let calculatedYAnchorPoint = (0.5 - relativeAnchorPoint.y) * CGFloat((heightConstraint?.constant ?? 0) + textPadding.top + textPadding.bottom)

        horizontalPositionConstraint?.constant = calculatedXPosition + calculatedXAnchorPoint
        verticalPositionConstraint?.constant = calculatedYPosition + calculatedYAnchorPoint
    }
}

fileprivate extension UILabel {
    static func makeCaption() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        if #available(iOS 13.0, *) {
            label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            label.font = .preferredFont(forTextStyle: .caption1)
        }
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        return label
    }
}

fileprivate extension UIView {
    static func makeBackground() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isOpaque = false
        view.backgroundColor = .black
        return view
    }

    /// Calculate potential frame size by providing character count for one line and line count in total
    /// - Parameters:
    ///   - characters: Count for characters in one line
    ///   - lineCount: Count for lines
    ///   - font: Provided font for the potential string
    /// - Returns: Size of the frame which can contain the string in provided character and line count
    func calculatePossibleFrameSize(forCharacterCountInLine characters: Int, lineCount: Int, font: UIFont) -> CGSize {
        let attributes: [NSAttributedString.Key : Any] = [.font: font]
        let string = String(repeating: "W", count: characters) as NSString
        let size = string.boundingRect(with: CGSize(width: .max, height: .max), options: [.usesLineFragmentOrigin], attributes: attributes, context: nil).size
        return CGSize(width: ceil(size.width), height: ceil(size.height) * CGFloat(lineCount))
    }
}
