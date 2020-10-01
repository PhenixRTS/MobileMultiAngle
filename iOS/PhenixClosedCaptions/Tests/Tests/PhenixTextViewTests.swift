//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

@testable import PhenixClosedCaptions
import XCTest

class PhenixTextViewTests: XCTestCase {
    func testViewInitialization() {
        let view = PhenixTextView()
        XCTAssertNotNil(view)
    }

    func testViewPositionIsTopLeft() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.0, y: 0.0)
        sut.relativePositionInSuperview = .init(x: 0.0, y: 0.0)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.minX, superview.frame.minX)
        XCTAssertEqual(sut.frame.minY, superview.frame.minY)
    }

    func testViewPositionIsTopCenter() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.5, y: 0.0)
        sut.relativePositionInSuperview = .init(x: 0.5, y: 0.0)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.midX, superview.frame.midX)
        XCTAssertEqual(sut.frame.minY, superview.frame.minY)
    }

    func testViewPositionIsTopRight() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 1.0, y: 0.0)
        sut.relativePositionInSuperview = .init(x: 1.0, y: 0.0)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.maxX, superview.frame.maxX)
        XCTAssertEqual(sut.frame.minY, superview.frame.minY)
    }

    func testViewPositionIsMiddleLeft() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.0, y: 0.5)
        sut.relativePositionInSuperview = .init(x: 0.0, y: 0.5)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.minX, superview.frame.minX)
        XCTAssertEqual(sut.frame.midY, superview.frame.midY)
    }

    func testViewPositionIsMiddleCenter() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.5, y: 0.5)
        sut.relativePositionInSuperview = .init(x: 0.5, y: 0.5)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.midX, superview.frame.midX)
        XCTAssertEqual(sut.frame.midY, superview.frame.midY)
    }

    func testViewPositionIsMiddleRight() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 1.0, y: 0.5)
        sut.relativePositionInSuperview = .init(x: 1.0, y: 0.5)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.maxX, superview.frame.maxX)
        XCTAssertEqual(sut.frame.midY, superview.frame.midY)
    }

    func testViewPositionIsBottomLeft() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.0, y: 1.0)
        sut.relativePositionInSuperview = .init(x: 0.0, y: 1.0)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.minX, superview.frame.minX)
        XCTAssertEqual(sut.frame.maxY, superview.frame.maxY)
    }

    func testViewPositionIsBottomCenter() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.5, y: 1.0)
        sut.relativePositionInSuperview = .init(x: 0.5, y: 1.0)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.midX, superview.frame.midX)
        XCTAssertEqual(sut.frame.maxY, superview.frame.maxY)
    }

    func testViewPositionIsBottomRight() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 1.0, y: 1.0)
        sut.relativePositionInSuperview = .init(x: 1.0, y: 1.0)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.maxX, superview.frame.maxX)
        XCTAssertEqual(sut.frame.maxY, superview.frame.maxY)
    }

    func testViewPositionWithCenteredAnchorPoint() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.5, y: 0.5)
        sut.relativePositionInSuperview = .init(x: 0.75, y: 0.75)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.midX, superview.frame.maxX * 0.75)
        XCTAssertEqual(sut.frame.midY, superview.frame.maxY * 0.75)
    }

    func testViewPositionWithLeftSideAnchorPoint() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 0.0, y: 0.5)
        sut.relativePositionInSuperview = .init(x: 0.75, y: 0.75)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.minX, superview.frame.maxX * 0.75)
        XCTAssertEqual(sut.frame.midY, superview.frame.maxY * 0.75)
    }

    func testViewPositionWithRightSideAnchorPoint() {
        // Given
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let sut = PhenixTextView()
        sut.translatesAutoresizingMaskIntoConstraints = false
        sut.caption = "Test"

        // When
        sut.relativeAnchorPoint = .init(x: 1.0, y: 0.5)
        sut.relativePositionInSuperview = .init(x: 0.75, y: 0.75)
        superview.addSubview(sut)
        superview.layoutIfNeeded()

        // Then
        XCTAssertEqual(sut.frame.maxX, superview.frame.maxX * 0.75)
        XCTAssertEqual(sut.frame.midY, superview.frame.maxY * 0.75)
    }
}
