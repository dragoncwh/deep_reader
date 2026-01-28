//
//  BookTests.swift
//  DeepReaderTests
//
//  Unit tests for Book model
//

import XCTest
@testable import DeepReader

final class BookTests: XCTestCase {

    // MARK: - Reading Progress Tests

    func testReadingProgress_whenPageCountIsZero_returnsZero() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 0,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 5,
            coverImagePath: nil
        )

        XCTAssertEqual(book.readingProgress, 0)
    }

    func testReadingProgress_whenAtFirstPage_returnsZero() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        XCTAssertEqual(book.readingProgress, 0)
    }

    func testReadingProgress_whenHalfway_returnsFiftyPercent() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 50,
            coverImagePath: nil
        )

        XCTAssertEqual(book.readingProgress, 0.5, accuracy: 0.001)
    }

    func testReadingProgress_whenCompleted_returnsOne() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 100,
            coverImagePath: nil
        )

        XCTAssertEqual(book.readingProgress, 1.0)
    }

    func testReadingProgress_withVariousValues() {
        let testCases: [(lastReadPage: Int, pageCount: Int, expected: Double)] = [
            (0, 10, 0.0),
            (1, 10, 0.1),
            (5, 10, 0.5),
            (10, 10, 1.0),
            (25, 100, 0.25),
            (75, 100, 0.75),
            (33, 99, 1.0/3.0),
        ]

        for testCase in testCases {
            let book = Book(
                id: 1,
                title: "Test Book",
                author: nil,
                filePath: "/path/to/book.pdf",
                fileSize: 1024,
                pageCount: testCase.pageCount,
                addedAt: Date(),
                lastOpenedAt: nil,
                lastReadPage: testCase.lastReadPage,
                coverImagePath: nil
            )

            XCTAssertEqual(
                book.readingProgress,
                testCase.expected,
                accuracy: 0.001,
                "Failed for lastReadPage: \(testCase.lastReadPage), pageCount: \(testCase.pageCount)"
            )
        }
    }

    // MARK: - Formatted File Size Tests

    func testFormattedFileSize_bytes() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 500,
            pageCount: 10,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        // ByteCountFormatter returns localized string, so we check it's not empty
        XCTAssertFalse(book.formattedFileSize.isEmpty)
    }

    func testFormattedFileSize_kilobytes() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 10,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        let formatted = book.formattedFileSize
        XCTAssertFalse(formatted.isEmpty)
        // Should contain "KB" or localized equivalent
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("kB") || formatted.contains("1"))
    }

    func testFormattedFileSize_megabytes() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 5 * 1024 * 1024, // 5 MB
            pageCount: 10,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        let formatted = book.formattedFileSize
        XCTAssertFalse(formatted.isEmpty)
        // Should contain "MB" or localized equivalent
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("5"))
    }

    func testFormattedFileSize_zero() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 0,
            pageCount: 10,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        let formatted = book.formattedFileSize
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("0") || formatted.lowercased().contains("zero"))
    }

    // MARK: - Model Initialization Tests

    func testBookInitialization_withAllFields() {
        let addedDate = Date()
        let openedDate = Date()

        let book = Book(
            id: 42,
            title: "Swift Programming",
            author: "Apple Inc.",
            filePath: "/Documents/Books/swift.pdf",
            fileSize: 2048000,
            pageCount: 250,
            addedAt: addedDate,
            lastOpenedAt: openedDate,
            lastReadPage: 125,
            coverImagePath: "/Documents/Covers/42.jpg"
        )

        XCTAssertEqual(book.id, 42)
        XCTAssertEqual(book.title, "Swift Programming")
        XCTAssertEqual(book.author, "Apple Inc.")
        XCTAssertEqual(book.filePath, "/Documents/Books/swift.pdf")
        XCTAssertEqual(book.fileSize, 2048000)
        XCTAssertEqual(book.pageCount, 250)
        XCTAssertEqual(book.addedAt, addedDate)
        XCTAssertEqual(book.lastOpenedAt, openedDate)
        XCTAssertEqual(book.lastReadPage, 125)
        XCTAssertEqual(book.coverImagePath, "/Documents/Covers/42.jpg")
    }

    func testBookInitialization_withMinimalFields() {
        let book = Book(
            id: nil,
            title: "Untitled",
            author: nil,
            filePath: "/path/to/file.pdf",
            fileSize: 0,
            pageCount: 0,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        XCTAssertNil(book.id)
        XCTAssertEqual(book.title, "Untitled")
        XCTAssertNil(book.author)
        XCTAssertNil(book.lastOpenedAt)
        XCTAssertNil(book.coverImagePath)
    }

    // MARK: - Hashable & Equatable Tests

    func testBookHashable() {
        let book1 = Book(
            id: 1,
            title: "Book",
            author: nil,
            filePath: "/path/1.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        let book2 = Book(
            id: 2,
            title: "Book",
            author: nil,
            filePath: "/path/2.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        var set = Set<Book>()
        set.insert(book1)
        set.insert(book2)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Database Table Name

    func testDatabaseTableName() {
        XCTAssertEqual(Book.databaseTableName, "books")
    }
}
