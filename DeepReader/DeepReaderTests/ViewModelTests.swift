//
//  ViewModelTests.swift
//  DeepReaderTests
//
//  Unit tests for ViewModels
//  Note: ReaderViewModel and AppState are @MainActor classes which have
//  deallocation issues in Swift 6 strict concurrency mode. These tests
//  are commented out until a proper solution is found.
//

import XCTest
@testable import DeepReader

// MARK: - Test Helpers

extension Book {
    static func makeTestBook(
        id: Int64? = 1,
        title: String = "Test Book",
        author: String? = nil,
        filePath: String = "/path/to/book.pdf",
        fileSize: Int64 = 1024,
        pageCount: Int = 100,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        lastReadPage: Int = 0,
        coverImagePath: String? = nil
    ) -> Book {
        Book(
            id: id,
            title: title,
            author: author,
            filePath: filePath,
            fileSize: fileSize,
            pageCount: pageCount,
            addedAt: addedAt,
            lastOpenedAt: lastOpenedAt,
            lastReadPage: lastReadPage,
            coverImagePath: coverImagePath
        )
    }
}

// MARK: - Book Model Additional Tests

final class BookModelTests: XCTestCase {

    func testBook_makeTestBook_createsValidBook() {
        let book = Book.makeTestBook()

        XCTAssertEqual(book.id, 1)
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.pageCount, 100)
    }

    func testBook_makeTestBook_customValues() {
        let book = Book.makeTestBook(
            id: 42,
            title: "Custom Book",
            author: "Custom Author",
            pageCount: 200,
            lastReadPage: 50
        )

        XCTAssertEqual(book.id, 42)
        XCTAssertEqual(book.title, "Custom Book")
        XCTAssertEqual(book.author, "Custom Author")
        XCTAssertEqual(book.pageCount, 200)
        XCTAssertEqual(book.lastReadPage, 50)
    }

    func testBook_readingProgress_withCustomValues() {
        let book = Book.makeTestBook(pageCount: 200, lastReadPage: 100)

        XCTAssertEqual(book.readingProgress, 0.5, accuracy: 0.001)
    }
}
