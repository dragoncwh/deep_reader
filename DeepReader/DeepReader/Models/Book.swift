//
//  Book.swift
//  DeepReader
//
//  Book model representing a PDF document
//

import Foundation
import GRDB

/// Represents a book/PDF document in the library
struct Book: Identifiable, Hashable, Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "books"

    var id: Int64?
    var title: String
    var author: String?
    var filePath: String
    var fileSize: Int64
    var pageCount: Int
    var addedAt: Date
    var lastOpenedAt: Date?
    var lastReadPage: Int
    var coverImagePath: String?

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
