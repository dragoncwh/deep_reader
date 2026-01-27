//
//  DatabaseService.swift
//  DeepReader
//
//  SQLite database service using GRDB
//

import Foundation
import GRDB

/// Main database service for the app
final class DatabaseService {
    
    /// Shared instance
    static let shared = DatabaseService()
    
    /// Database queue for all operations
    private var dbQueue: DatabaseQueue?
    
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
            db.trace { print("SQL: \($0)") }
        }
        #endif
        
        dbQueue = try DatabaseQueue(path: databasePath, configuration: config)
        try migrate()
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
        
        try migrator.migrate(dbQueue)
    }
    
    // MARK: - Books
    
    /// Fetch all books ordered by last opened
    func fetchBooks() throws -> [Book] {
        try dbQueue!.read { db in
            try Book
                .order(Book.Columns.lastOpenedAt.desc.nullsLast)
                .order(Book.Columns.addedAt.desc)
                .fetchAll(db)
        }
    }
    
    /// Insert or update a book
    func saveBook(_ book: inout Book) throws {
        try dbQueue!.write { db in
            try book.save(db)
        }
    }
    
    /// Delete a book
    func deleteBook(_ book: Book) throws {
        try dbQueue!.write { db in
            try book.delete(db)
        }
    }
    
    /// Update reading progress
    func updateReadingProgress(bookId: Int64, page: Int) throws {
        try dbQueue!.write { db in
            try db.execute(
                sql: "UPDATE books SET lastReadPage = ?, lastOpenedAt = ? WHERE id = ?",
                arguments: [page, Date(), bookId]
            )
        }
    }
    
    // MARK: - Highlights
    
    /// Fetch highlights for a book
    func fetchHighlights(bookId: Int64) throws -> [Highlight] {
        try dbQueue!.read { db in
            try Highlight
                .filter(Highlight.Columns.bookId == bookId)
                .order(Highlight.Columns.pageNumber)
                .order(Highlight.Columns.createdAt)
                .fetchAll(db)
        }
    }
    
    /// Save a highlight
    func saveHighlight(_ highlight: inout Highlight) throws {
        try dbQueue!.write { db in
            try highlight.save(db)
        }
    }
    
    /// Delete a highlight
    func deleteHighlight(_ highlight: Highlight) throws {
        try dbQueue!.write { db in
            try highlight.delete(db)
        }
    }
    
    // MARK: - Text Search
    
    /// Store extracted text for a page
    func storeTextContent(bookId: Int64, pageNumber: Int, text: String) throws {
        try dbQueue!.write { db in
            try db.execute(
                sql: "INSERT INTO text_content (bookId, pageNumber, text) VALUES (?, ?, ?)",
                arguments: [bookId, pageNumber, text]
            )
        }
    }
    
    /// Full-text search across all books
    func searchText(query: String) throws -> [(bookId: Int64, pageNumber: Int, snippet: String)] {
        try dbQueue!.read { db in
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
