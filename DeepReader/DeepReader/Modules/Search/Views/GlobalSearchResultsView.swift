//
//  GlobalSearchResultsView.swift
//  DeepReader
//
//  Global search results view for searching across all books
//

import SwiftUI

/// View displaying search results across all books in the library
struct GlobalSearchResultsView: View {
    /// The search query text
    let searchText: String

    /// Callback when a search result is tapped
    var onResultTapped: ((SearchResult) -> Void)?

    @State private var results: [SearchResult] = []
    @State private var isLoading = false
    @State private var hasSearched = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if results.isEmpty && hasSearched {
                emptyResultsView
            } else if results.isEmpty {
                promptView
            } else {
                resultsList
            }
        }
        .task(id: searchText) {
            await performSearch()
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Results State

    private var emptyResultsView: some View {
        ContentUnavailableView(
            "No Results Found",
            systemImage: "magnifyingglass",
            description: Text("No matches found for \"\(searchText)\".\nTry different keywords or check your spelling.")
        )
    }

    // MARK: - Initial Prompt State

    private var promptView: some View {
        ContentUnavailableView(
            "Search Your Library",
            systemImage: "text.magnifyingglass",
            description: Text("Enter a search term to find text across all your books.")
        )
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(results) { result in
                GlobalSearchResultRow(result: result) {
                    onResultTapped?(result)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Search Logic

    private func performSearch() async {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            results = []
            hasSearched = false
            return
        }

        // Debounce: wait 300ms before searching
        // If the user types again, .task(id:) cancels this task and starts a new one
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            // Task was cancelled during sleep (user typed again)
            return
        }

        // Double-check cancellation after sleep
        guard !Task.isCancelled else { return }

        isLoading = true

        do {
            results = try DatabaseService.shared.searchTextWithBookInfo(query: trimmedQuery)
            hasSearched = true
        } catch {
            // Check if error is due to cancellation
            if Task.isCancelled { return }
            Logger.shared.error("Global search failed: \(error.localizedDescription)")
            results = []
            hasSearched = true
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview("With Results") {
    GlobalSearchResultsView(
        searchText: "example",
        onResultTapped: { result in
            print("Tapped: \(result.bookTitle) - Page \(result.pageNumber)")
        }
    )
}

#Preview("Empty Search") {
    GlobalSearchResultsView(searchText: "")
}
