//
//  Highlight.swift
//  DeepReader
//
//  Highlight annotation model
//

import Foundation
import GRDB
import SwiftUI

/// Represents a text highlight in a PDF document
struct Highlight: Identifiable, Hashable {
    var id: Int64?
    let bookId: Int64
    let pageNumber: Int
    let text: String
    let note: String?
    let color: HighlightColor
    let createdAt: Date
    
    /// Bounding boxes for the highlight (JSON encoded)
    let boundsData: Data
    
    init(
        id: Int64? = nil,
        bookId: Int64,
        pageNumber: Int,
        text: String,
        note: String? = nil,
        color: HighlightColor = .yellow,
        createdAt: Date = Date(),
        bounds: [CGRect]
    ) {
        self.id = id
        self.bookId = bookId
        self.pageNumber = pageNumber
        self.text = text
        self.note = note
        self.color = color
        self.createdAt = createdAt
        self.boundsData = (try? JSONEncoder().encode(bounds)) ?? Data()
    }
    
    var bounds: [CGRect] {
        (try? JSONDecoder().decode([CGRect].self, from: boundsData)) ?? []
    }
}

// MARK: - Highlight Color
enum HighlightColor: String, Codable, CaseIterable {
    case yellow
    case green
    case blue
    case pink
    case purple
    
    var color: Color {
        switch self {
        case .yellow: return .yellow.opacity(0.4)
        case .green: return .green.opacity(0.4)
        case .blue: return .blue.opacity(0.4)
        case .pink: return .pink.opacity(0.4)
        case .purple: return .purple.opacity(0.4)
        }
    }
}

// MARK: - GRDB Codable Record
extension Highlight: Codable, FetchableRecord, MutablePersistableRecord {
    
    static let databaseTableName = "highlights"
    
    enum Columns: String, ColumnExpression {
        case id, bookId, pageNumber, text, note, color, createdAt, boundsData
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
