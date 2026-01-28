//
//  ViewModelTests.swift
//  DeepReaderTests
//
//  Unit tests for ViewModels
//

import XCTest
@testable import DeepReader

final class ReaderViewModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testReaderViewModel_initialization_setsBookAndCurrentPage() {
        let book = Book(
            id: 1,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 25,
            coverImagePath: nil
        )

        let viewModel = ReaderViewModel(book: book)

        XCTAssertEqual(viewModel.book.id, book.id)
        XCTAssertEqual(viewModel.book.title, book.title)
        XCTAssertEqual(viewModel.currentPage, 25)
    }

    func testReaderViewModel_initialization_startsWithNoDocument() {
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

        let viewModel = ReaderViewModel(book: book)

        XCTAssertNil(viewModel.document)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Page Count Tests

    func testReaderViewModel_pageCount_withNoDocument_returnsZero() {
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

        let viewModel = ReaderViewModel(book: book)

        XCTAssertEqual(viewModel.pageCount, 0)
    }

    // MARK: - Search Tests

    func testReaderViewModel_search_withEmptyQuery_clearsResults() {
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

        let viewModel = ReaderViewModel(book: book)
        viewModel.search(query: "")

        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    func testReaderViewModel_search_withNoDocument_clearsResults() {
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

        let viewModel = ReaderViewModel(book: book)
        viewModel.search(query: "test")

        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }
}

// MARK: - AppState Tests

final class AppStateTests: XCTestCase {

    func testAppState_initialization_defaultValues() {
        let appState = AppState()

        XCTAssertNil(appState.selectedBook)
        XCTAssertFalse(appState.isShowingImporter)
    }

    func testAppState_selectedBook_canBeSet() {
        let appState = AppState()
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

        appState.selectedBook = book

        XCTAssertNotNil(appState.selectedBook)
        XCTAssertEqual(appState.selectedBook?.title, "Test Book")
    }

    func testAppState_selectedBook_canBeCleared() {
        let appState = AppState()
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

        appState.selectedBook = book
        appState.selectedBook = nil

        XCTAssertNil(appState.selectedBook)
    }

    func testAppState_isShowingImporter_canBeToggled() {
        let appState = AppState()

        XCTAssertFalse(appState.isShowingImporter)

        appState.isShowingImporter = true
        XCTAssertTrue(appState.isShowingImporter)

        appState.isShowingImporter = false
        XCTAssertFalse(appState.isShowingImporter)
    }
}

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
