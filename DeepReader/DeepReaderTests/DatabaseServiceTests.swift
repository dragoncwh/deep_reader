//
//  DatabaseServiceTests.swift
//  DeepReaderTests
//
//  Unit tests for DatabaseService using in-memory database
//

import XCTest
import GRDB
@testable import DeepReader

/// Testable database service that uses a temporary file database
/// Marked as Sendable to work with Swift 6 concurrency
final class TestDatabaseService: @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let dbPath: String

    nonisolated init() throws {
        // Create temporary file database to avoid memory management issues
        let tempDir = FileManager.default.temporaryDirectory
        dbPath = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite").path
        dbQueue = try DatabaseQueue(path: dbPath)
        try migrate()
    }

    deinit {
        // Clean up temporary database file
        try? FileManager.default.removeItem(atPath: dbPath)
    }

    private nonisolated func migrate() throws {
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

        // Add OCR flag for scanned PDFs
        migrator.registerMigration("v4_ocr_flag") { db in
            try db.alter(table: "books") { t in
                t.add(column: "needsOCR", .boolean).notNull().defaults(to: false)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Books

    nonisolated func fetchBooks() throws -> [Book] {
        try dbQueue.read { db in
            try Book
                .order(sql: "CASE WHEN lastOpenedAt IS NULL THEN 1 ELSE 0 END, lastOpenedAt DESC, addedAt DESC")
                .fetchAll(db)
        }
    }

    nonisolated func saveBook(_ book: inout Book) throws {
        try dbQueue.write { db in
            try book.save(db)
        }
    }

    nonisolated func deleteBook(_ book: Book) throws {
        try dbQueue.write { db in
            try book.delete(db)
        }
    }

    nonisolated func updateReadingProgress(bookId: Int64, page: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE books SET lastReadPage = ?, lastOpenedAt = ? WHERE id = ?",
                arguments: [page, Date(), bookId]
            )
        }
    }

    // MARK: - Highlights

    nonisolated func fetchHighlights(bookId: Int64) throws -> [Highlight] {
        try dbQueue.read { db in
            try Highlight
                .filter(sql: "bookId = ?", arguments: [bookId])
                .order(sql: "pageNumber, createdAt")
                .fetchAll(db)
        }
    }

    nonisolated func saveHighlight(_ highlight: inout Highlight) throws {
        try dbQueue.write { db in
            try highlight.save(db)
        }
    }

    nonisolated func deleteHighlight(_ highlight: Highlight) throws {
        try dbQueue.write { db in
            try highlight.delete(db)
        }
    }

    // MARK: - Text Search

    nonisolated func storeTextContent(bookId: Int64, pages: [(page: Int, text: String)]) throws {
        try dbQueue.write { db in
            for page in pages {
                try db.execute(
                    sql: "INSERT INTO text_content (bookId, pageNumber, text) VALUES (?, ?, ?)",
                    arguments: [bookId, page.page, page.text]
                )
            }
        }
    }

    nonisolated func searchText(query: String) throws -> [(bookId: Int64, pageNumber: Int, snippet: String)] {
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

    // Create a fresh database for each test
    private nonisolated func makeDatabase() throws -> TestDatabaseService {
        try TestDatabaseService()
    }

    // MARK: - Book CRUD Tests

    func testSaveAndFetchBook() throws {
        let database = try makeDatabase()
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
        let database = try makeDatabase()
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
            author: "Author 2",
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
        let database = try makeDatabase()
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
        let originalId = book.id

        book.title = "Updated Title"
        book.author = "New Author"
        try database.saveBook(&book)

        XCTAssertEqual(book.id, originalId)

        let books = try database.fetchBooks()
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books[0].title, "Updated Title")
        XCTAssertEqual(books[0].author, "New Author")
    }

    func testDeleteBook() throws {
        let database = try makeDatabase()
        var book = Book(
            id: nil,
            title: "Book to Delete",
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

    func testFetchBooksOrdering() throws {
        let database = try makeDatabase()
        let now = Date()

        var book1 = Book(
            id: nil,
            title: "Never Opened",
            author: nil,
            filePath: "/path/to/book1.pdf",
            fileSize: 1024,
            pageCount: 50,
            addedAt: now.addingTimeInterval(-100),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )

        var book2 = Book(
            id: nil,
            title: "Opened First",
            author: nil,
            filePath: "/path/to/book2.pdf",
            fileSize: 1024,
            pageCount: 50,
            addedAt: now.addingTimeInterval(-200),
            lastOpenedAt: now.addingTimeInterval(-50),
            lastReadPage: 0,
            coverImagePath: nil
        )

        var book3 = Book(
            id: nil,
            title: "Opened Recently",
            author: nil,
            filePath: "/path/to/book3.pdf",
            fileSize: 1024,
            pageCount: 50,
            addedAt: now.addingTimeInterval(-300),
            lastOpenedAt: now.addingTimeInterval(-10),
            lastReadPage: 0,
            coverImagePath: nil
        )

        try database.saveBook(&book1)
        try database.saveBook(&book2)
        try database.saveBook(&book3)

        let books = try database.fetchBooks()

        // Recently opened books first, then never opened
        XCTAssertEqual(books[0].title, "Opened Recently")
        XCTAssertEqual(books[1].title, "Opened First")
        XCTAssertEqual(books[2].title, "Never Opened")
    }

    func testUpdateReadingProgress() throws {
        let database = try makeDatabase()
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

        try database.updateReadingProgress(bookId: book.id!, page: 42)

        let books = try database.fetchBooks()
        XCTAssertEqual(books[0].lastReadPage, 42)
        XCTAssertNotNil(books[0].lastOpenedAt)
    }

    // MARK: - Highlight CRUD Tests

    func testSaveAndFetchHighlights() throws {
        let database = try makeDatabase()
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

        var highlight = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 5,
            text: "Highlighted text",
            note: "My note",
            color: .yellow,
            createdAt: Date(),
            boundsData: Data()
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
        let database = try makeDatabase()
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

        var highlight = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 5,
            text: "To be deleted",
            note: nil,
            color: .green,
            createdAt: Date(),
            boundsData: Data()
        )
        try database.saveHighlight(&highlight)

        XCTAssertEqual(try database.fetchHighlights(bookId: book.id!).count, 1)

        try database.deleteHighlight(highlight)

        XCTAssertEqual(try database.fetchHighlights(bookId: book.id!).count, 0)
    }

    func testCascadeDeleteHighlightsWhenBookDeleted() throws {
        let database = try makeDatabase()
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

        var highlight1 = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 1,
            text: "Highlight 1",
            note: nil,
            color: .yellow,
            createdAt: Date(),
            boundsData: Data()
        )

        var highlight2 = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 2,
            text: "Highlight 2",
            note: nil,
            color: .blue,
            createdAt: Date(),
            boundsData: Data()
        )

        try database.saveHighlight(&highlight1)
        try database.saveHighlight(&highlight2)

        XCTAssertEqual(try database.fetchHighlights(bookId: book.id!).count, 2)

        // Delete book should cascade delete highlights
        try database.deleteBook(book)

        // Create another book to verify highlights are truly deleted
        var newBook = Book(
            id: nil,
            title: "New Book",
            author: nil,
            filePath: "/path/to/newbook.pdf",
            fileSize: 512,
            pageCount: 50,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        )
        try database.saveBook(&newBook)

        XCTAssertEqual(try database.fetchHighlights(bookId: newBook.id!).count, 0)
    }

    func testHighlightsSortedByPageAndCreatedAt() throws {
        let database = try makeDatabase()
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

        let now = Date()

        var h1 = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 10,
            text: "Page 10",
            note: nil,
            color: .yellow,
            createdAt: now,
            boundsData: Data()
        )

        var h2 = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 5,
            text: "Page 5",
            note: nil,
            color: .green,
            createdAt: now.addingTimeInterval(-100),
            boundsData: Data()
        )

        var h3 = Highlight(
            id: nil,
            bookId: book.id!,
            pageNumber: 5,
            text: "Page 5 later",
            note: nil,
            color: .blue,
            createdAt: now,
            boundsData: Data()
        )

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
        let database = try makeDatabase()
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
        let database = try makeDatabase()
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
        let database = try makeDatabase()
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

        try database.storeTextContent(bookId: book1.id!, pages: [
            (page: 0, text: "Introduction to programming")
        ])

        try database.storeTextContent(bookId: book2.id!, pages: [
            (page: 0, text: "Advanced programming techniques")
        ])

        let results = try database.searchText(query: "programming")
        XCTAssertEqual(results.count, 2)

        let bookIds = Set(results.map { $0.bookId })
        XCTAssertTrue(bookIds.contains(book1.id!))
        XCTAssertTrue(bookIds.contains(book2.id!))
    }
}
