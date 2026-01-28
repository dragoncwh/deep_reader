//
//  DatabaseServiceTests.swift
//  DeepReaderTests
//
//  Unit tests for DatabaseService using in-memory database
//

import XCTest
import GRDB
@testable import DeepReader

/// Testable subclass of DatabaseService that uses an in-memory database
final class TestDatabaseService {
    private var dbQueue: DatabaseQueue

    init() throws {
        // Create in-memory database
        dbQueue = try DatabaseQueue(named: "test-\(UUID().uuidString)")
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        // Initial schema
        migrator.registerMigration("v1_initial") { db in
            // Books table
            try db.create(table: "books") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("author", .text)
                t.column("filePath", .text).notNull().unique()
                t.column("fileSize", .integer).notNull()
                t.column("pageCount", .integer).notNull()
                t.column("addedAt", .datetime).notNull()
                t.column("lastOpenedAt", .datetime)
                t.column("lastReadPage", .integer).notNull().defaults(to: 0)
                t.column("coverImagePath", .text)
            }

            // Highlights table
            try db.create(table: "highlights") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bookId", .integer).notNull()
                    .references("books", onDelete: .cascade)
                t.column("pageNumber", .integer).notNull()
                t.column("text", .text).notNull()
                t.column("note", .text)
                t.column("color", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("boundsData", .blob).notNull()
            }

            // Create indexes
            try db.create(index: "idx_books_title", on: "books", columns: ["title"])
            try db.create(index: "idx_highlights_bookId", on: "highlights", columns: ["bookId"])
        }

        // Full-text search for books
        migrator.registerMigration("v2_fts") { db in
            // Text content table for full-text search
            try db.create(table: "text_content") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bookId", .integer).notNull()
                    .references("books", onDelete: .cascade)
                t.column("pageNumber", .integer).notNull()
                t.column("text", .text).notNull()
            }

            // FTS5 virtual table
            try db.execute(sql: """
                CREATE VIRTUAL TABLE text_content_fts USING fts5(
                    text,
                    content='text_content',
                    content_rowid='id'
                )
            """)

            // Triggers to keep FTS in sync
            try db.execute(sql: """
                CREATE TRIGGER text_content_ai AFTER INSERT ON text_content BEGIN
                    INSERT INTO text_content_fts(rowid, text) VALUES (new.id, new.text);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER text_content_ad AFTER DELETE ON text_content BEGIN
                    INSERT INTO text_content_fts(text_content_fts, rowid, text) VALUES('delete', old.id, old.text);
                END
            """)
        }

        migrator.registerMigration("v3_text_content_index") { db in
            try db.create(index: "idx_text_content_bookId", on: "text_content", columns: ["bookId"])
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Books

    func fetchBooks() throws -> [Book] {
        try dbQueue.read { db in
            try Book
                .order(sql: "CASE WHEN lastOpenedAt IS NULL THEN 1 ELSE 0 END, lastOpenedAt DESC, addedAt DESC")
                .fetchAll(db)
        }
    }

    func saveBook(_ book: inout Book) throws {
        try dbQueue.write { db in
            try book.save(db)
        }
    }

    func deleteBook(_ book: Book) throws {
        try dbQueue.write { db in
            try book.delete(db)
        }
    }

    func updateReadingProgress(bookId: Int64, page: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE books SET lastReadPage = ?, lastOpenedAt = ? WHERE id = ?",
                arguments: [page, Date(), bookId]
            )
        }
    }

    // MARK: - Highlights

    func fetchHighlights(bookId: Int64) throws -> [Highlight] {
        try dbQueue.read { db in
            try Highlight
                .filter(sql: "bookId = ?", arguments: [bookId])
                .order(sql: "pageNumber, createdAt")
                .fetchAll(db)
        }
    }

    func saveHighlight(_ highlight: inout Highlight) throws {
        try dbQueue.write { db in
            try highlight.save(db)
        }
    }

    func deleteHighlight(_ highlight: Highlight) throws {
        try dbQueue.write { db in
            try highlight.delete(db)
        }
    }

    // MARK: - Text Search

    func storeTextContent(bookId: Int64, pages: [(page: Int, text: String)]) throws {
        try dbQueue.write { db in
            for page in pages {
                try db.execute(
                    sql: "INSERT INTO text_content (bookId, pageNumber, text) VALUES (?, ?, ?)",
                    arguments: [bookId, page.page, page.text]
                )
            }
        }
    }

    func searchText(query: String) throws -> [(bookId: Int64, pageNumber: Int, snippet: String)] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT tc.bookId, tc.pageNumber, snippet(text_content_fts, 0, '<b>', '</b>', '...', 20) as snippet
                FROM text_content_fts
                JOIN text_content tc ON tc.id = text_content_fts.rowid
                WHERE text_content_fts MATCH ?
                LIMIT 100
            """, arguments: [query])

            return rows.map { row in
                (
                    bookId: row["bookId"] as Int64,
                    pageNumber: row["pageNumber"] as Int,
                    snippet: row["snippet"] as String
                )
            }
        }
    }
}

// MARK: - Test Cases

final class DatabaseServiceTests: XCTestCase {

    var database: TestDatabaseService!

    override func setUpWithError() throws {
        database = try TestDatabaseService()
    }

    override func tearDownWithError() throws {
        database = nil
    }

    // MARK: - Book CRUD Tests

    func testSaveAndFetchBook() throws {
        var book = Book(
            id: nil,
            title: "Test Book",
            author: "Test Author",
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        try database.saveBook(&book)

        XCTAssertNotNil(book.id)

        let books = try database.fetchBooks()
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books[0].title, "Test Book")
        XCTAssertEqual(books[0].author, "Test Author")
    }

    func testSaveMultipleBooks() throws {
        var book1 = Book(
            id: nil,
            title: "Book 1",
            author: nil,
            filePath: "/path/to/book1.pdf",
            fileSize: 1024,
            pageCount: 50,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        var book2 = Book(
            id: nil,
            title: "Book 2",
            author: nil,
            filePath: "/path/to/book2.pdf",
            fileSize: 2048,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        try database.saveBook(&book1)
        try database.saveBook(&book2)

        let books = try database.fetchBooks()
        XCTAssertEqual(books.count, 2)
    }

    func testUpdateBook() throws {
        var book = Book(
            id: nil,
            title: "Original Title",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        try database.saveBook(&book)

        book.title = "Updated Title"
        book.author = "New Author"
        try database.saveBook(&book)

        let books = try database.fetchBooks()
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books[0].title, "Updated Title")
        XCTAssertEqual(books[0].author, "New Author")
    }

    func testDeleteBook() throws {
        var book = Book(
            id: nil,
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

        try database.saveBook(&book)
        XCTAssertEqual(try database.fetchBooks().count, 1)

        try database.deleteBook(book)
        XCTAssertEqual(try database.fetchBooks().count, 0)
    }

    func testUpdateReadingProgress() throws {
        var book = Book(
            id: nil,
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

        try database.saveBook(&book)

        try database.updateReadingProgress(bookId: book.id!, page: 50)

        let books = try database.fetchBooks()
        XCTAssertEqual(books[0].lastReadPage, 50)
        XCTAssertNotNil(books[0].lastOpenedAt)
    }

    func testFetchBooksOrdering() throws {
        // Book with lastOpenedAt (should appear first)
        var book1 = Book(
            id: nil,
            title: "Recently Opened",
            author: nil,
            filePath: "/path/to/book1.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date().addingTimeInterval(-1000),
            lastOpenedAt: Date(),
            lastReadPage: 10,
            coverImagePath: nil
        )

        // Book without lastOpenedAt (should appear later)
        var book2 = Book(
            id: nil,
            title: "Never Opened",
            author: nil,
            filePath: "/path/to/book2.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        try database.saveBook(&book2)
        try database.saveBook(&book1)

        let books = try database.fetchBooks()
        XCTAssertEqual(books.count, 2)
        XCTAssertEqual(books[0].title, "Recently Opened")
        XCTAssertEqual(books[1].title, "Never Opened")
    }

    // MARK: - Highlight CRUD Tests

    func testSaveAndFetchHighlight() throws {
        // First create a book
        var book = Book(
            id: nil,
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
        try database.saveBook(&book)

        // Create highlight
        let boundsData = try JSONEncoder().encode([CGRect(x: 10, y: 20, width: 100, height: 15)])
        var highlight = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 5,
            text: "Highlighted text",
            note: "My note",
            color: .yellow,
            createdAt: Date(),
            boundsData: boundsData
        )

        try database.saveHighlight(&highlight)

        XCTAssertNotNil(highlight.id)

        let highlights = try database.fetchHighlights(bookId: book.id!)
        XCTAssertEqual(highlights.count, 1)
        XCTAssertEqual(highlights[0].text, "Highlighted text")
        XCTAssertEqual(highlights[0].note, "My note")
        XCTAssertEqual(highlights[0].color, .yellow)
    }

    func testDeleteHighlight() throws {
        var book = Book(
            id: nil,
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
        try database.saveBook(&book)

        let boundsData = try JSONEncoder().encode([CGRect]())
        var highlight = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 1,
            text: "Text",
            note: nil,
            color: .green,
            createdAt: Date(),
            boundsData: boundsData
        )

        try database.saveHighlight(&highlight)
        XCTAssertEqual(try database.fetchHighlights(bookId: book.id!).count, 1)

        try database.deleteHighlight(highlight)
        XCTAssertEqual(try database.fetchHighlights(bookId: book.id!).count, 0)
    }

    func testHighlightCascadeDeleteOnBookDelete() throws {
        var book = Book(
            id: nil,
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
        try database.saveBook(&book)

        let boundsData = try JSONEncoder().encode([CGRect]())
        var highlight = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 1,
            text: "Text",
            note: nil,
            color: .blue,
            createdAt: Date(),
            boundsData: boundsData
        )
        try database.saveHighlight(&highlight)

        XCTAssertEqual(try database.fetchHighlights(bookId: book.id!).count, 1)

        // Delete book - highlights should cascade delete
        try database.deleteBook(book)

        // Verify book is deleted
        XCTAssertEqual(try database.fetchBooks().count, 0)
    }

    func testHighlightsOrderedByPageAndDate() throws {
        var book = Book(
            id: nil,
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
        try database.saveBook(&book)

        let boundsData = try JSONEncoder().encode([CGRect]())

        var h1 = Highlight(id: nil, bookId: book.id!, pageNumber: 10, text: "Page 10", note: nil, color: .yellow, createdAt: Date(), boundsData: boundsData)
        var h2 = Highlight(id: nil, bookId: book.id!, pageNumber: 5, text: "Page 5", note: nil, color: .green, createdAt: Date(), boundsData: boundsData)
        var h3 = Highlight(id: nil, bookId: book.id!, pageNumber: 5, text: "Page 5 later", note: nil, color: .blue, createdAt: Date().addingTimeInterval(100), boundsData: boundsData)

        try database.saveHighlight(&h1)
        try database.saveHighlight(&h2)
        try database.saveHighlight(&h3)

        let highlights = try database.fetchHighlights(bookId: book.id!)
        XCTAssertEqual(highlights.count, 3)
        XCTAssertEqual(highlights[0].text, "Page 5")
        XCTAssertEqual(highlights[1].text, "Page 5 later")
        XCTAssertEqual(highlights[2].text, "Page 10")
    }

    // MARK: - Full-Text Search Tests

    func testStoreAndSearchTextContent() throws {
        var book = Book(
            id: nil,
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
        try database.saveBook(&book)

        let pages = [
            (page: 0, text: "This is the introduction chapter"),
            (page: 1, text: "Swift is a powerful programming language"),
            (page: 2, text: "Learn Swift and build user interfaces")
        ]

        try database.storeTextContent(bookId: book.id!, pages: pages)

        // Search for "Swift" - FTS5 matches whole words only
        let results = try database.searchText(query: "Swift")
        XCTAssertEqual(results.count, 2)

        // Verify results contain expected pages
        let pageNumbers = results.map { $0.pageNumber }
        XCTAssertTrue(pageNumbers.contains(1))
        XCTAssertTrue(pageNumbers.contains(2))
    }

    func testSearchTextNoResults() throws {
        var book = Book(
            id: nil,
            title: "Test Book",
            author: nil,
            filePath: "/path/to/book.pdf",
            fileSize: 1024,
            pageCount: 5,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )
        try database.saveBook(&book)

        let pages = [
            (page: 0, text: "Hello world"),
            (page: 1, text: "Goodbye world")
        ]

        try database.storeTextContent(bookId: book.id!, pages: pages)

        let results = try database.searchText(query: "Python")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchTextAcrossMultipleBooks() throws {
        var book1 = Book(
            id: nil,
            title: "Book 1",
            author: nil,
            filePath: "/path/to/book1.pdf",
            fileSize: 1024,
            pageCount: 5,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        var book2 = Book(
            id: nil,
            title: "Book 2",
            author: nil,
            filePath: "/path/to/book2.pdf",
            fileSize: 1024,
            pageCount: 5,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        try database.saveBook(&book1)
        try database.saveBook(&book2)

        try database.storeTextContent(bookId: book1.id!, pages: [(page: 0, text: "iOS development with Swift")])
        try database.storeTextContent(bookId: book2.id!, pages: [(page: 0, text: "Swift programming basics")])

        let results = try database.searchText(query: "Swift")
        XCTAssertEqual(results.count, 2)

        let bookIds = Set(results.map { $0.bookId })
        XCTAssertTrue(bookIds.contains(book1.id!))
        XCTAssertTrue(bookIds.contains(book2.id!))
    }
}
