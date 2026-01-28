//
//  DatabaseService.swift
//  DeepReader
//
//  SQLite database service using GRDB
//

import Foundation
import GRDB

/// Database service errors
enum DatabaseServiceError: LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database has not been initialized"
        }
    }
}

/// Main database service for the app
final class DatabaseService {

    /// Shared instance
    static let shared = DatabaseService()

    /// Database queue for all operations
    private var dbQueue: DatabaseQueue?

    /// Safe access to database queue
    private func queue() throws -> DatabaseQueue {
        guard let dbQueue else {
            throw DatabaseServiceError.notInitialized
        }
        return dbQueue
    }
    
    /// Database file path
    private var databasePath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("deep_reader.sqlite").path
    }
    
    private init() {}
    
    // MARK: - Setup
    
    /// Initialize the database
    func setup() throws {
        var config = Configuration()
        #if DEBUG
        config.prepareDatabase { db in
            db.trace { Logger.shared.debug("SQL: \($0)") }
        }
        #endif

        dbQueue = try DatabaseQueue(path: databasePath, configuration: config)
        try migrate()
        Logger.shared.info("Database initialized at: \(databasePath)")
    }
    
    /// Run database migrations
    private func migrate() throws {
        guard let dbQueue = dbQueue else { return }
        
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

        // Add index for faster text_content lookups by bookId
        migrator.registerMigration("v3_text_content_index") { db in
            try db.create(index: "idx_text_content_bookId", on: "text_content", columns: ["bookId"])
        }

        try migrator.migrate(dbQueue)
    }
    
    // MARK: - Books
    
    /// Fetch all books ordered by last opened
    func fetchBooks() throws -> [Book] {
        try queue().read { db in
            try Book
                .order(sql: "CASE WHEN lastOpenedAt IS NULL THEN 1 ELSE 0 END, lastOpenedAt DESC, addedAt DESC")
                .fetchAll(db)
        }
    }

    /// Insert or update a book
    func saveBook(_ book: inout Book) throws {
        try queue().write { db in
            try book.save(db)
        }
    }

    /// Delete a book
    func deleteBook(_ book: Book) throws {
        try queue().write { db in
            try book.delete(db)
        }
    }

    /// Update reading progress
    func updateReadingProgress(bookId: Int64, page: Int) throws {
        try queue().write { db in
            try db.execute(
                sql: "UPDATE books SET lastReadPage = ?, lastOpenedAt = ? WHERE id = ?",
                arguments: [page, Date(), bookId]
            )
        }
    }
    
    // MARK: - Highlights

    /// Fetch highlights for a book
    func fetchHighlights(bookId: Int64) throws -> [Highlight] {
        try queue().read { db in
            try Highlight
                .filter(sql: "bookId = ?", arguments: [bookId])
                .order(sql: "pageNumber, createdAt")
                .fetchAll(db)
        }
    }

    /// Save a highlight
    func saveHighlight(_ highlight: inout Highlight) throws {
        try queue().write { db in
            try highlight.save(db)
        }
    }

    /// Delete a highlight
    func deleteHighlight(_ highlight: Highlight) throws {
        try queue().write { db in
            try highlight.delete(db)
        }
    }

    // MARK: - Text Search

    /// Store extracted text for multiple pages using batch insert
    func storeTextContent(bookId: Int64, pages: [(page: Int, text: String)]) throws {
        guard !pages.isEmpty else { return }

        try queue().write { db in
            // Use prepared statement for better performance
            let statement = try db.makeStatement(
                sql: "INSERT INTO text_content (bookId, pageNumber, text) VALUES (?, ?, ?)"
            )

            for page in pages {
                try statement.execute(arguments: [bookId, page.page, page.text])
            }
        }
    }

    /// Full-text search across all books with relevance ranking
    /// - Parameter query: Search query (supports FTS5 syntax)
    /// - Returns: Results sorted by relevance (bm25 score)
    func searchText(query: String) throws -> [(bookId: Int64, pageNumber: Int, snippet: String, rank: Double)] {
        guard !query.isEmpty else { return [] }

        return try queue().read { db in
            // Use bm25() for relevance ranking (lower score = more relevant)
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    tc.bookId,
                    tc.pageNumber,
                    snippet(text_content_fts, 0, '<b>', '</b>', '...', 32) as snippet,
                    bm25(text_content_fts) as rank
                FROM text_content_fts
                JOIN text_content tc ON tc.id = text_content_fts.rowid
                WHERE text_content_fts MATCH ?
                ORDER BY rank
                LIMIT 100
            """, arguments: [query])

            return rows.map { row in
                (
                    bookId: row["bookId"] as Int64,
                    pageNumber: row["pageNumber"] as Int,
                    snippet: row["snippet"] as String,
                    rank: row["rank"] as Double
                )
            }
        }
    }

    /// Full-text search within a specific book
    func searchTextInBook(bookId: Int64, query: String) throws -> [(pageNumber: Int, snippet: String)] {
        guard !query.isEmpty else { return [] }

        return try queue().read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    tc.pageNumber,
                    snippet(text_content_fts, 0, '<b>', '</b>', '...', 32) as snippet
                FROM text_content_fts
                JOIN text_content tc ON tc.id = text_content_fts.rowid
                WHERE text_content_fts MATCH ? AND tc.bookId = ?
                ORDER BY tc.pageNumber
                LIMIT 200
            """, arguments: [query, bookId])

            return rows.map { row in
                (
                    pageNumber: row["pageNumber"] as Int,
                    snippet: row["snippet"] as String
                )
            }
        }
    }
}
