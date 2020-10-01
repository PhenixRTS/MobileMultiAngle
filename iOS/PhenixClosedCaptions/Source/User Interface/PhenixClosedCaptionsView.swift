//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import UIKit

public class PhenixClosedCaptionsView: UIView {
    internal private(set) var textViews: [UInt: PhenixTextView] = [:]

    // MARK: - Public properties

    /// View property configuration
    public var configuration: PhenixClosedCaptionsConfiguration = .default {
        didSet {
            os_log(.debug, log: .containerView, "View configuration changed: %{PRIVATE}s", String(reflecting: configuration))
        }
    }

    internal override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    internal required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func layoutSubviews() {
        textViews.forEach { $0.value.setNeedsUpdateConstraints() }
        super.layoutSubviews()
    }

    internal func getWindowIndexList() -> Set<UInt> {
        Set(textViews.map(\.key))
    }

    internal func update(_ window: PhenixWindowUpdate, forWindow index: UInt) {
        // Retrieve the view from the set
        let textView = getTextView(withIndex: index)

        // TODO: Make those properties "sticky" in the cache.

        if let backgroundAlpha = window.backgroundAlpha {
            textView.backgroundAlpha = backgroundAlpha
        }

        if let justify = window.justify {
            textView.justify = justify
        }

        if let backgroundColor = UIColor(hex: window.backgroundColor) {
            textView.backgroundColor = backgroundColor
        }

        if let wordWrap = window.wordWrap {
            textView.wordWrap = wordWrap
        }

        if let zOrder = window.zOrder {
            textView.zOrder = zOrder
        }

        if let visible = window.visible {
            textView.isHidden = visible == false
        }

        if let anchorPointOnTextWindow = window.anchorPointOnTextWindow?.cgPoint {
            textView.relativeAnchorPoint = anchorPointOnTextWindow
            textView.setNeedsUpdateConstraints()
        }

        if let positionOfTextWindow = window.positionOfTextWindow?.cgPoint {
            textView.relativePositionInSuperview = positionOfTextWindow
            textView.setNeedsUpdateConstraints()
        }

        if let widthInCharacters = window.widthInCharacters {
            textView.widthInCharacters = widthInCharacters
            textView.setNeedsUpdateConstraints()
        }

        if let heightInTextLines = window.heightInTextLines {
            textView.heightInTextLines = heightInTextLines
            textView.setNeedsUpdateConstraints()
        }
    }

    internal func update(_ texts: [PhenixTextUpdate], forWindow index: UInt) {
        // Retrieve the view from the set
        let textView = getTextView(withIndex: index)

        // Combine captions from all `PhenixTextUpdate` objects together into one string
        let caption: String = texts
            .map { $0.caption }
            .reduce("", +)

        // Configure the text view.
        textView.caption = caption

        // If the caption is empty, then we need to hide the view (but not remove the view)
        textView.isHidden = caption.isEmpty
    }

    internal func remove(windowWithIndex index: UInt) {
        let window = textViews.removeValue(forKey: index)
        window?.removeFromSuperview()
    }

    internal func removeAllWindows() {
        textViews.forEach { $0.value.removeFromSuperview() }
        textViews.removeAll()
    }

    internal func getTextView(withIndex index: UInt) -> PhenixTextView {
        // Retrieve the view from the set or create a new one.
        let textView = textViews[index] ?? PhenixTextView()

        if textViews[index] == nil { // If the textView didn't exist...
            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.tag = Int(index)
            setDefaultVisualization(for: textView)

            // Add to the container.
            addSubview(textView)

            // Insert into the view set.
            textViews[index] = textView
        }

        return textView
    }
}

private extension PhenixClosedCaptionsView {
    func setup() {
        isOpaque = false
        backgroundColor = .clear
    }

    func setDefaultVisualization(for textView: PhenixTextView) {
        textView.backgroundAlpha = configuration.textBackgroundAlpha
        textView.justify = configuration.justify
        textView.backgroundColor = configuration.textBackgroundColor
        textView.wordWrap = configuration.wordWrap
        textView.zOrder = configuration.zOrder
        textView.isHidden = configuration.visible == false
        textView.relativeAnchorPoint = configuration.anchorPointOnTextWindow
        textView.relativePositionInSuperview = configuration.positionOfTextWindow
        textView.widthInCharacters = configuration.widthInCharacters
        textView.heightInTextLines = configuration.heightInTextLines
    }
}
