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
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.books.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.books) { book in
                        NavigationLink(value: book) {
                            BookCardView(book: book)
                        }
                        .buttonStyle(.plain)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                
                if let coverPath = book.coverImagePath {
                    // TODO: Load actual cover image
                    AsyncImage(url: URL(fileURLWithPath: coverPath)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        coverPlaceholder
                    }
                } else {
                    coverPlaceholder
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
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
}

// MARK: - View Model
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false

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

        // TODO: Load from DatabaseService
        // For now, use sample data
        books = []
    }

    func deleteBook(_ book: Book) async {
        // TODO: Implement deletion
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(AppState())
    }
}
