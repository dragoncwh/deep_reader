//
//  HighlightTests.swift
//  DeepReaderTests
//
//  Unit tests for Highlight model and HighlightColor enum
//

import XCTest
import SwiftUI
@testable import DeepReader

final class HighlightTests: XCTestCase {

    // MARK: - HighlightColor Tests

    func testHighlightColor_allCases() {
        let allCases = HighlightColor.allCases

        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.yellow))
        XCTAssertTrue(allCases.contains(.green))
        XCTAssertTrue(allCases.contains(.blue))
        XCTAssertTrue(allCases.contains(.pink))
        XCTAssertTrue(allCases.contains(.purple))
    }

    func testHighlightColor_rawValues() {
        XCTAssertEqual(HighlightColor.yellow.rawValue, "yellow")
        XCTAssertEqual(HighlightColor.green.rawValue, "green")
        XCTAssertEqual(HighlightColor.blue.rawValue, "blue")
        XCTAssertEqual(HighlightColor.pink.rawValue, "pink")
        XCTAssertEqual(HighlightColor.purple.rawValue, "purple")
    }

    func testHighlightColor_initFromRawValue() {
        XCTAssertEqual(HighlightColor(rawValue: "yellow"), .yellow)
        XCTAssertEqual(HighlightColor(rawValue: "green"), .green)
        XCTAssertEqual(HighlightColor(rawValue: "blue"), .blue)
        XCTAssertEqual(HighlightColor(rawValue: "pink"), .pink)
        XCTAssertEqual(HighlightColor(rawValue: "purple"), .purple)
        XCTAssertNil(HighlightColor(rawValue: "invalid"))
    }

    func testHighlightColor_colorProperty_returnsNonNilColor() {
        for highlightColor in HighlightColor.allCases {
            // Each color should return a valid SwiftUI Color
            let _ = highlightColor.color
            // If we reach here without crashing, the color is valid
        }
    }

    // MARK: - Highlight Bounds Tests

    func testHighlightBounds_withValidData() throws {
        let originalBounds = [
            CGRect(x: 10, y: 20, width: 100, height: 15),
            CGRect(x: 10, y: 40, width: 80, height: 15)
        ]
        let boundsData = try JSONEncoder().encode(originalBounds)

        let highlight = Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 5,
            text: "Sample text",
            note: nil,
            color: .yellow,
            createdAt: Date(),
            boundsData: boundsData
        )

        let decodedBounds = highlight.bounds

        XCTAssertEqual(decodedBounds.count, 2)
        XCTAssertEqual(decodedBounds[0], originalBounds[0])
        XCTAssertEqual(decodedBounds[1], originalBounds[1])
    }

    func testHighlightBounds_withEmptyData() {
        let highlight = Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 5,
            text: "Sample text",
            note: nil,
            color: .yellow,
            createdAt: Date(),
            boundsData: Data()
        )

        let bounds = highlight.bounds

        XCTAssertTrue(bounds.isEmpty)
    }

    func testHighlightBounds_withInvalidData() {
        let invalidData = "not a valid json".data(using: .utf8)!

        let highlight = Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 5,
            text: "Sample text",
            note: nil,
            color: .yellow,
            createdAt: Date(),
            boundsData: invalidData
        )

        let bounds = highlight.bounds

        // Should return empty array on decode failure
        XCTAssertTrue(bounds.isEmpty)
    }

    func testHighlightBounds_withSingleRect() throws {
        let originalBounds = [CGRect(x: 0, y: 0, width: 50, height: 10)]
        let boundsData = try JSONEncoder().encode(originalBounds)

        let highlight = Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 1,
            text: "Word",
            note: nil,
            color: .green,
            createdAt: Date(),
            boundsData: boundsData
        )

        XCTAssertEqual(highlight.bounds.count, 1)
        XCTAssertEqual(highlight.bounds[0], CGRect(x: 0, y: 0, width: 50, height: 10))
    }

    // MARK: - Highlight Initialization Tests

    func testHighlightInitialization_withAllFields() throws {
        let createdDate = Date()
        let boundsData = try JSONEncoder().encode([CGRect(x: 0, y: 0, width: 100, height: 20)])

        let highlight = Highlight(
            id: 42,
            bookId: 10,
            pageNumber: 25,
            text: "This is highlighted text",
            note: "Important note",
            color: .blue,
            createdAt: createdDate,
            boundsData: boundsData
        )

        XCTAssertEqual(highlight.id, 42)
        XCTAssertEqual(highlight.bookId, 10)
        XCTAssertEqual(highlight.pageNumber, 25)
        XCTAssertEqual(highlight.text, "This is highlighted text")
        XCTAssertEqual(highlight.note, "Important note")
        XCTAssertEqual(highlight.color, .blue)
        XCTAssertEqual(highlight.createdAt, createdDate)
    }

    func testHighlightInitialization_withNilNote() throws {
        let boundsData = try JSONEncoder().encode([CGRect]())

        let highlight = Highlight(
            id: nil,
            bookId: 1,
            pageNumber: 1,
            text: "Text",
            note: nil,
            color: .yellow,
            createdAt: Date(),
            boundsData: boundsData
        )

        XCTAssertNil(highlight.id)
        XCTAssertNil(highlight.note)
    }

    // MARK: - Database Table Name

    func testDatabaseTableName() {
        XCTAssertEqual(Highlight.databaseTableName, "highlights")
    }

    // MARK: - Hashable Tests

    func testHighlightHashable() throws {
        let boundsData = try JSONEncoder().encode([CGRect]())

        let highlight1 = Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 1,
            text: "Text 1",
            note: nil,
            color: .yellow,
            createdAt: Date(),
            boundsData: boundsData
        )

        let highlight2 = Highlight(
            id: 2,
            bookId: 1,
            pageNumber: 1,
            text: "Text 2",
            note: nil,
            color: .green,
            createdAt: Date(),
            boundsData: boundsData
        )

        var set = Set<Highlight>()
        set.insert(highlight1)
        set.insert(highlight2)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Codable Tests

    func testHighlightColor_encodeDecode() throws {
        let original = HighlightColor.purple

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HighlightColor.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testHighlight_encodeDecode() throws {
        let boundsData = try JSONEncoder().encode([CGRect(x: 10, y: 20, width: 30, height: 40)])
        let originalDate = Date()

        let original = Highlight(
            id: 100,
            bookId: 5,
            pageNumber: 10,
            text: "Test highlight",
            note: "Test note",
            color: .pink,
            createdAt: originalDate,
            boundsData: boundsData
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Highlight.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.bookId, original.bookId)
        XCTAssertEqual(decoded.pageNumber, original.pageNumber)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.note, original.note)
        XCTAssertEqual(decoded.color, original.color)
        XCTAssertEqual(decoded.boundsData, original.boundsData)
    }
}
