//
//  SearchResult.swift
//  DeepReader
//
//  Search result model for global text search
//

import Foundation

/// Represents a search result from full-text search across all books
struct SearchResult: Identifiable {
    /// Unique identifier for the search result (combines bookId and pageNumber)
    var id: String { "\(bookId)-\(pageNumber)" }

    /// The book containing this result
    let bookId: Int64

    /// Title of the book
    let bookTitle: String

    /// Page number where the match was found
    let pageNumber: Int

    /// Text snippet with match highlighted
    let snippet: String

    /// BM25 relevance score (lower = more relevant)
    let rank: Double
}
