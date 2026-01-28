//
//  GlobalSearchResultRow.swift
//  DeepReader
//
//  Reusable row component for global search results
//

import SwiftUI

/// A row displaying a single global search result with highlighted keywords
struct GlobalSearchResultRow: View {
    /// The search result to display
    let result: SearchResult

    /// Callback when the row is tapped
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Book title
                Text(result.bookTitle)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Page number
                Text("Page \(result.pageNumber)")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)

                // Snippet with highlighted keywords
                highlightedSnippet(result.snippet)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Snippet Highlighting

    /// Parses the snippet and highlights text between <b>...</b> tags
    private func highlightedSnippet(_ snippet: String) -> Text {
        var result = Text("")
        var remaining = snippet

        while let openRange = remaining.range(of: "<b>") {
            // Text before the <b> tag
            let beforeTag = String(remaining[..<openRange.lowerBound])
            if !beforeTag.isEmpty {
                result = result + Text(beforeTag)
            }

            // Move past the <b> tag
            remaining = String(remaining[openRange.upperBound...])

            // Find the closing </b> tag
            if let closeRange = remaining.range(of: "</b>") {
                // Extract the highlighted text
                let highlightedText = String(remaining[..<closeRange.lowerBound])
                result = result + Text(highlightedText)
                    .bold()
                    .foregroundColor(.readerAccent)

                // Move past the </b> tag
                remaining = String(remaining[closeRange.upperBound...])
            } else {
                // No closing tag found, append the rest as-is
                result = result + Text(remaining)
                remaining = ""
            }
        }

        // Append any remaining text after the last tag
        if !remaining.isEmpty {
            result = result + Text(remaining)
        }

        return result
    }
}

// MARK: - Preview

#Preview("With Highlighted Keywords") {
    List {
        GlobalSearchResultRow(
            result: SearchResult(
                bookId: 1,
                bookTitle: "Sample Book Title",
                pageNumber: 42,
                snippet: "This is a <b>sample</b> snippet with <b>highlighted</b> keywords.",
                rank: 1.0
            ),
            onTap: { print("Tapped") }
        )

        GlobalSearchResultRow(
            result: SearchResult(
                bookId: 2,
                bookTitle: "Another Book with a Very Long Title That Should Truncate",
                pageNumber: 123,
                snippet: "The <b>search</b> term appears multiple times. Here is another <b>search</b> match in the text.",
                rank: 2.0
            ),
            onTap: { print("Tapped") }
        )
    }
    .listStyle(.plain)
}

#Preview("Without Highlighted Keywords") {
    List {
        GlobalSearchResultRow(
            result: SearchResult(
                bookId: 1,
                bookTitle: "Plain Text Book",
                pageNumber: 5,
                snippet: "This snippet has no highlighted keywords at all.",
                rank: 1.0
            ),
            onTap: { print("Tapped") }
        )
    }
    .listStyle(.plain)
}
