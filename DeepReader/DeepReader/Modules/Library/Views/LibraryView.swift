//
//  LibraryView.swift
//  DeepReader
//
//  Book library grid view
//

import SwiftUI
import Combine

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LibraryViewModel()
    @State private var bookToDelete: Book?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
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
                            BookCardView(book: book, coverCache: viewModel.coverCache)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
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
        .navigationTitle("Library")
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
}

// MARK: - Book Card View
struct BookCardView: View {
    let book: Book
    let coverCache: CoverImageCache
    @State private var coverImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image
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
final class CoverImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        // Limit cache to ~50 images
        cache.countLimit = 50
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
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .bookImported)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadBooks()
                }
            }
            .store(in: &cancellables)
    }

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
