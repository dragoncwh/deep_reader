//
//  LibraryView.swift
//  DeepReader
//
//  Book library grid view
//

import SwiftUI
import UIKit
import Combine

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LibraryViewModel()
    @ObservedObject private var ocrService = OCRService.shared
    @State private var bookToDelete: Book?
    @State private var searchText: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        Group {
            if searchText.isEmpty {
                libraryContentView
            } else {
                globalSearchResultsView
            }
        }
        .navigationTitle("Library")
        .searchable(text: $searchText, prompt: "Search books and content")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.isShowingImporter = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.loadBooks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookImported)) { _ in
            Task {
                await viewModel.loadBooks()
            }
        }
        .alert("Delete Book", isPresented: .init(
            get: { bookToDelete != nil },
            set: { if !$0 { bookToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                bookToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let book = bookToDelete {
                    Task {
                        await viewModel.deleteBook(book)
                    }
                }
                bookToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(bookToDelete?.title ?? "")\"? This cannot be undone.")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Books Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to add your first PDF")
                .foregroundStyle(.secondary)

            Button {
                appState.isShowingImporter = true
            } label: {
                Label("Add PDF", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var libraryContentView: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.books.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.books) { book in
                        NavigationLink(value: book) {
                            BookCardView(
                                book: book,
                                coverCache: viewModel.coverCache,
                                needsOCR: book.needsOCR,
                                ocrProgress: book.id.flatMap { ocrService.ocrProgress[$0] }
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if book.needsOCR {
                                Button {
                                    ocrService.processBook(book)
                                } label: {
                                    Label("Process Scanned PDF", systemImage: "doc.viewfinder")
                                }
                            }

                            Button(role: .destructive) {
                                bookToDelete = book
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // Global search results view
    private var globalSearchResultsView: some View {
        GlobalSearchResultsView(
            searchText: searchText,
            onResultTapped: { result in
                navigateToSearchResult(result)
            }
        )
    }

    /// Navigate to a book at a specific page from a search result
    private func navigateToSearchResult(_ result: SearchResult) {
        do {
            // Fetch the book by ID
            guard let book = try DatabaseService.shared.fetchBook(id: result.bookId) else {
                Logger.shared.error("Book not found for search result: \(result.bookId)")
                return
            }

            // Set the initial page to navigate to
            appState.initialPage = result.pageNumber

            // Clear search text to dismiss search interface
            searchText = ""

            // Navigate to the book using NavigationLink's value-based navigation
            // The navigationPath is managed by ContentView's NavigationStack
            appState.selectedBook = book
        } catch {
            Logger.shared.error("Failed to fetch book for navigation: \(error.localizedDescription)")
        }
    }
}

// MARK: - Book Card View
struct BookCardView: View {
    let book: Book
    let coverCache: CoverImageCache
    var needsOCR: Bool = false
    var ocrProgress: Double? = nil
    @State private var coverImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))

                    if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        coverPlaceholder
                    }
                }

                // OCR status badge
                ocrStatusBadge
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .task {
                await loadCoverImage()
            }

            // Book info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Progress indicator
                if book.readingProgress > 0 {
                    ProgressView(value: book.readingProgress)
                        .tint(.accentColor)
                }
            }
        }
    }

    private var coverPlaceholder: some View {
        VStack {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("PDF")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// OCR status badge overlay
    @ViewBuilder
    private var ocrStatusBadge: some View {
        if let progress = ocrProgress {
            // OCR in progress - show circular progress indicator
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)

                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
            }
            .padding(Spacing.sm)
        } else if needsOCR {
            // Needs OCR - show scan icon badge
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)

                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.sm)
        }
    }

    private func loadCoverImage() async {
        guard let coverPath = book.coverImagePath else { return }

        // Check cache first
        if let cached = coverCache.image(forKey: coverPath) {
            coverImage = cached
            return
        }

        // Load from disk in background
        let image = await Task.detached(priority: .background) {
            UIImage(contentsOfFile: coverPath)
        }.value

        if let image = image {
            coverCache.setImage(image, forKey: coverPath)
            await MainActor.run {
                self.coverImage = image
            }
        }
    }
}

// MARK: - Cover Image Cache
// Note: @unchecked Sendable is required because NSCache is not Sendable on iOS 16.
// This can be removed when minimum deployment target is raised to iOS 17+.
final class CoverImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        // Limit cache to ~50 images
        cache.countLimit = 50

        // Listen for memory warnings to clear cache
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - View Model
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false

    let coverCache = CoverImageCache()

    func loadBooks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            books = try BookService.shared.fetchAllBooks()
        } catch {
            Logger.shared.error("Failed to load books: \(error.localizedDescription)")
            books = []
        }
    }

    func deleteBook(_ book: Book) async {
        do {
            try BookService.shared.deleteBook(book)
            coverCache.clear() // Clear cache when deleting
            await loadBooks()
        } catch {
            Logger.shared.error("Failed to delete book: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(AppState())
    }
}
