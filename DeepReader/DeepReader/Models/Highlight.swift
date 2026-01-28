//
//  Highlight.swift
//  DeepReader
//
//  Highlight annotation model
//

import Foundation
import GRDB
import SwiftUI

/// Highlight color options
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

    /// UIColor for PDFAnnotation (full opacity - annotation handles alpha)
    var uiColor: UIColor {
        switch self {
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .pink: return .systemPink
        case .purple: return .systemPurple
        }
    }
}

/// Represents a text highlight in a PDF document
struct Highlight: Identifiable, Hashable, Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "highlights"

    var id: Int64?
    var bookId: Int64
    var pageNumber: Int
    var text: String
    var note: String?
    var color: HighlightColor
    var createdAt: Date
    var boundsData: Data

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    var bounds: [CGRect] {
        (try? JSONDecoder().decode([CGRect].self, from: boundsData)) ?? []
    }
}
