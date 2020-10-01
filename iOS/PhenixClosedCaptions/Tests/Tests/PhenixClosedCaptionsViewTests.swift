//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

@testable import PhenixClosedCaptions
import XCTest

class PhenixClosedCaptionsViewTests: XCTestCase {
    func testViewInitialization() {
        let view = PhenixClosedCaptionsView()
        XCTAssertNotNil(view)
    }

    func testViewDefaultConfiguration() {
        let sut = PhenixClosedCaptionsView()
        XCTAssertEqual(sut.configuration, PhenixClosedCaptionsConfiguration.default)
    }

    func testViewChangeConfiguration() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let customConfiguration = PhenixClosedCaptionsConfiguration(anchorPointOnTextWindow: .zero, positionOfTextWindow: .zero, widthInCharacters: 0, heightInTextLines: 0, textBackgroundColor: .black, textBackgroundAlpha: .zero, visible: true, zOrder: .zero, justify: .center, wordWrap: true)

        // When
        sut.configuration = customConfiguration

        // Then
        XCTAssertEqual(sut.configuration, customConfiguration)
    }

    func testViewCreatesNewTextView() {
        // Given
        let sut = PhenixClosedCaptionsView()
        XCTAssertEqual(sut.textViews.count, 0)

        // When
        let _ = sut.getTextView(withIndex: 0)

        // Then
        XCTAssertEqual(sut.textViews.count, 1)
    }

    func testViewProvidesDefaultConfigurationToTextView() {
        // Given
        let sut = PhenixClosedCaptionsView()

        // When
        let textView = sut.getTextView(withIndex: 0)

        // Then
        XCTAssertEqual(textView.relativeAnchorPoint, sut.configuration.anchorPointOnTextWindow)
        XCTAssertEqual(textView.relativePositionInSuperview, sut.configuration.positionOfTextWindow)
        XCTAssertEqual(textView.widthInCharacters, sut.configuration.widthInCharacters)
        XCTAssertEqual(textView.heightInTextLines, sut.configuration.heightInTextLines)
        XCTAssertEqual(textView.backgroundColor, sut.configuration.textBackgroundColor)
        XCTAssertEqual(textView.backgroundAlpha, sut.configuration.textBackgroundAlpha)
        XCTAssertEqual(textView.isHidden, sut.configuration.visible == false)
        XCTAssertEqual(textView.zOrder, sut.configuration.zOrder)
        XCTAssertEqual(textView.justify, sut.configuration.justify)
        XCTAssertEqual(textView.wordWrap, sut.configuration.wordWrap)
    }

    func testViewUpdatesWindowParameters_backgroundAlpha() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(backgroundAlpha: 0.25)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.backgroundAlpha, windowUpdate.backgroundAlpha)
    }

    func testViewUpdatesWindowParameters_justify() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(justify: .left)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.justify, windowUpdate.justify)
    }

    func testViewUpdatesWindowParameters_backgroundColor() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(backgroundColor: "#00FF00") // Green color
        let backgroundColor = UIColor(hex: windowUpdate.backgroundColor)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.backgroundColor, backgroundColor)
    }

    func testViewUpdatesWindowParameters_wordWrap() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(wordWrap: false)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.wordWrap, windowUpdate.wordWrap)
    }

    func testViewUpdatesWindowParameters_zOrder() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(zOrder: 10)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.zOrder, windowUpdate.zOrder)
    }

    func testViewUpdatesWindowParameters_visible() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(visible: false)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.isHidden, windowUpdate.visible == false)
    }

    func testViewUpdatesWindowParameters_anchorPointOnTextWindow() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(anchorPointOnTextWindow: .init(x: 0.25, y: 0.25))

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.relativeAnchorPoint, windowUpdate.anchorPointOnTextWindow?.cgPoint)
    }

    func testViewUpdatesWindowParameters_positionOfTextWindow() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(positionOfTextWindow: .init(x: 0.25, y: 0.25))

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.relativePositionInSuperview, windowUpdate.positionOfTextWindow?.cgPoint)
    }

    func testViewUpdatesWindowParameters_widthInCharacters() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(widthInCharacters: 100)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.widthInCharacters, windowUpdate.widthInCharacters)
    }

    func testViewUpdatesWindowParameters_heightInTextLines() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let windowUpdate = PhenixWindowUpdate(heightInTextLines: 100)

        // When
        sut.update(windowUpdate, forWindow: 0)

        // Then
        XCTAssertEqual(textView.heightInTextLines, windowUpdate.heightInTextLines)
    }

    func testViewUpdatesTextParameters_caption() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let textUpdate = PhenixTextUpdate(timestamp: 123456789, caption: "Test Caption")

        // When
        sut.update([textUpdate], forWindow: 0)

        // Then
        XCTAssertEqual(textView.caption, textUpdate.caption)
    }

    func testViewUpdatesTextParameters_windowIsVisibleIfCaptionIsNotEmpty() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let textUpdate = PhenixTextUpdate(timestamp: 123456789, caption: "Test Caption")

        // When
        sut.update([textUpdate], forWindow: 0)

        // Then
        XCTAssertEqual(textView.isHidden, false)
    }

    func testViewUpdatesTextParameters_windowIsNotVisibleIfCaptionIsEmpty() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)
        let textUpdate = PhenixTextUpdate(timestamp: 123456789, caption: "")

        // When
        sut.update([textUpdate], forWindow: 0)

        // Then
        XCTAssertEqual(textView.isHidden, true)
    }

    func testViewUpdatesTextParameters_windowIsNotVisibleIfThereAreNoCaptionsProvided() {
        // Given
        let sut = PhenixClosedCaptionsView()
        let textView = sut.getTextView(withIndex: 0)

        // When
        sut.update([], forWindow: 0)

        // Then
        XCTAssertEqual(textView.isHidden, true)
    }

    func testCaptionTextIsConcatenated() {
        // Given
        let caption1 = "Lorem Ipsum"
        let caption2 = "Foo Bar"

        let sut = PhenixClosedCaptionsView()
        let textUpdates: [PhenixTextUpdate] = [
            PhenixTextUpdate(timestamp: 123456789, caption: caption1),
            PhenixTextUpdate(timestamp: 123456789, caption: caption2),
        ]

        // When
        sut.update(textUpdates, forWindow: 0)

        // Then
        let textView = sut.getTextView(withIndex: 0)
        XCTAssertEqual(textView.caption, "\(caption1)\(caption2)")
    }

    func testCaptionTextIsConcatenatedIncludingNewLinesAndSpaces() {
        // Given
        let caption1 = "  Lorem Ipsum  "
        let caption2 = "\nFoo Bar\n"

        let sut = PhenixClosedCaptionsView()
        let textUpdates: [PhenixTextUpdate] = [
            PhenixTextUpdate(timestamp: 123456789, caption: caption1),
            PhenixTextUpdate(timestamp: 123456789, caption: caption2),
        ]

        // When
        sut.update(textUpdates, forWindow: 0)

        // Then
        let textView = sut.getTextView(withIndex: 0)
        XCTAssertEqual(textView.caption, "\(caption1)\(caption2)")
    }
}
