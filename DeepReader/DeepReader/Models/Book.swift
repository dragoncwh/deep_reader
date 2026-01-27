//
//  Book.swift
//  DeepReader
//
//  Book model representing a PDF document
//

import Foundation
import GRDB

/// Represents a book/PDF document in the library
struct Book: Identifiable, Hashable {
    var id: Int64?
    let title: String
    let author: String?
    let filePath: String
    let fileSize: Int64
    let pageCount: Int
    let addedAt: Date
    var lastOpenedAt: Date?
    var lastReadPage: Int
    var coverImagePath: String?
    
    init(
        id: Int64? = nil,
        title: String,
        author: String? = nil,
        filePath: String,
        fileSize: Int64,
        pageCount: Int,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        lastReadPage: Int = 0,
        coverImagePath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.filePath = filePath
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.lastReadPage = lastReadPage
        self.coverImagePath = coverImagePath
    }
}

// MARK: - GRDB Codable Record
extension Book: Codable, FetchableRecord, MutablePersistableRecord {
    
    static let databaseTableName = "books"
    
    enum Columns: String, ColumnExpression {
        case id, title, author, filePath, fileSize, pageCount
        case addedAt, lastOpenedAt, lastReadPage, coverImagePath
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Convenience
extension Book {
    /// Returns a formatted file size string (e.g., "2.5 MB")
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Reading progress as percentage (0.0 - 1.0)
    var readingProgress: Double {
        guard pageCount > 0 else { return 0 }
        return Double(lastReadPage) / Double(pageCount)
    }
}
