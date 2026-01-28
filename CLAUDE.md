# DeepReader - Claude Code Instructions

## Project Overview

iOS PDF reader app focused on learning, with features for highlighting, notes, and full-text search. Built with SwiftUI, PDFKit, and GRDB.

## Build & Run

- **IDE**: Xcode (open `DeepReader/DeepReader.xcodeproj`)
- **Minimum iOS**: 16.0
- **Swift**: 5.9+
- **Dependencies**: GRDB.swift 7.0.0-beta.5+ (via SPM)

### Testing

```bash
# Run tests in Xcode or via command line
xcodebuild test -project DeepReader/DeepReader.xcodeproj -scheme DeepReader -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### Test Structure

```
DeepReaderTests/
├── BookTests.swift           # Book model tests (readingProgress, formattedFileSize)
├── HighlightTests.swift      # Highlight model + HighlightColor enum tests
├── DatabaseServiceTests.swift # Database CRUD, FTS5 search, cascade delete
├── ServiceErrorTests.swift   # LocalizedError conformance tests
└── ViewModelTests.swift      # Book helper extension tests
```

#### Testing Notes

- Uses `TestDatabaseService` with temporary file database for isolation
- Swift 6 strict concurrency mode requires `@unchecked Sendable` and `nonisolated` for test database service
- `@MainActor` ViewModels (AppState, ReaderViewModel) have deallocation issues in tests - avoid testing directly

## Architecture

### Pattern: MVVM with Singleton Services

```
DeepReader/DeepReader/
├── App/
│   ├── DeepReaderApp.swift     # @main entry point with AppState
│   └── ContentView.swift       # Root navigation & PDF import handling
├── Models/
│   ├── Book.swift              # GRDB-backed Book model
│   └── Highlight.swift         # GRDB-backed Highlight model + HighlightColor enum
├── Modules/
│   ├── Library/Views/
│   │   └── LibraryView.swift   # Library grid + LibraryViewModel + BookCardView + CoverImageCache
│   ├── Reader/Views/
│   │   ├── ReaderView.swift    # PDF reader + HighlightablePDFView + PDFKitView + SearchView + OutlineView + ReaderViewModel
│   │   ├── HighlightDetailView.swift # Highlight detail sheet (view/edit/delete)
│   │   ├── HighlightListView.swift   # Highlight list grouped by page
│   │   └── NoteEditorView.swift      # Note editor for highlights
│   └── Search/Views/
│       ├── GlobalSearchResultsView.swift # Global search results across all books
│       └── GlobalSearchResultRow.swift   # Search result row with highlighted keywords
├── Core/
│   ├── Logger/
│   │   └── Logger.swift        # Centralized logging service (OSLog)
│   ├── Storage/
│   │   ├── DatabaseService.swift
│   │   └── BookService.swift
│   └── PDF/
│       ├── PDFService.swift
│       └── OCRService.swift    # Background OCR processing for scanned PDFs
└── Shared/DesignSystem/
    └── DesignSystem.swift
```

### Key Services (Singletons)

- `DatabaseService.shared` - SQLite via GRDB, handles migrations, text search (FTS5 with bm25 ranking), highlights
- `PDFService.shared` - PDF loading, text extraction (with batching & progress), OCR (Vision), cover generation
- `BookService.shared` - PDF import, book CRUD, security-scoped file handling
- `OCRService.shared` - Background OCR processing queue for scanned PDFs (uses Vision framework)
- `Logger.shared` - Centralized logging using OSLog (debug/info/warning/error levels)

### ViewModels

- `AppState` (in DeepReaderApp.swift) - App-wide state: `selectedBook`, `isShowingImporter`
- `LibraryViewModel` (in LibraryView.swift) - Book list management
- `ReaderViewModel` (in ReaderView.swift) - PDF document state, search, navigation, highlights
  - `highlights: [Highlight]` - All highlights for current book
  - `highlightsByPage: [Int: [Highlight]]` - Highlights grouped by page
  - `createHighlight()`, `deleteHighlight()`, `updateHighlight()` - CRUD operations
  - `loadHighlights()`, `applyHighlightAnnotations()` - Load and render highlights

### UI Components

- `BookCardView` - Book cover with title, author, progress bar (uses CoverImageCache)
- `PDFKitView` - UIViewRepresentable wrapping `HighlightablePDFView` with text selection and highlight tap detection
  - **Navigation sync**: `updateUIView` must check if `currentPage` binding differs from PDFView's displayed page to handle programmatic navigation (outline, search, highlight list). Without this, only the page indicator updates while the PDF content doesn't scroll.
  - **Tap gesture**: Only triggers on highlight annotations (via `shouldReceive touch:`), allowing system menu to close normally on tap elsewhere.
- `HighlightablePDFView` - Custom PDFView subclass that integrates highlight colors into iOS system edit menu via `buildMenu(with:)`. Adds "Highlight" submenu with 5 color options after Copy.
- `SearchView` - Document text search interface (paginated results, 50 per page)
- `SearchResultRow` - Individual search result row component
- `OutlineView` - PDF table of contents navigation
- `CoverImageCache` - NSCache-based image caching (limit: 50 images)
- `HighlightDetailView` - Detail sheet for viewing/editing/deleting highlights (uses `sheet(item:)` pattern)
- `HighlightListView` - List of all highlights grouped by page number (uses `contentShape(Rectangle())` for full row tap area)
- `NoteEditorView` - Text editor for highlight notes
- `GlobalSearchResultsView` - Global search across all books with loading/empty states
- `GlobalSearchResultRow` - Search result row displaying book title, page, and snippet with highlighted keywords (parses `<b>` tags)

### Database

- SQLite via GRDB with FTS5 full-text search
- Tables: `books`, `highlights`, `text_content`, `text_content_fts`
- File: `Documents/deep_reader.sqlite`

## Code Patterns

### GRDB Models

Models conform to `Codable`, `FetchableRecord`, `MutablePersistableRecord`:

```swift
struct Book: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var title: String
    // ... other fields

    static let databaseTableName = "books"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

### Security-Scoped Resources

Always wrap file access for user-selected PDFs. **Important**: Always attempt file operations regardless of the return value - `startAccessingSecurityScopedResource()` returns `false` for files already in app sandbox, but they're still accessible:

```swift
let accessing = url.startAccessingSecurityScopedResource()
defer {
    if accessing {
        url.stopAccessingSecurityScopedResource()
    }
}
// Always attempt the file operation here, even if accessing == false
```

### Design System

Use design tokens from `DesignSystem.swift`:

- **Typography**: `AppTypography.title`, `.headline`, `.body`, `.caption`
- **Spacing**: `Spacing.xs` (4), `.sm` (8), `.md` (16), `.lg` (24), `.xl` (32)
- **Corner Radius**: `CornerRadius.small`, `.medium`, `.large`
- **Button Styles**: `.primary`, `.secondary`
- **Modifiers**: `.cardStyle()`, `.appShadow()`

### Async/Await

Use async/await for all async operations:

```swift
func extractAllText(from document: PDFDocument) async -> [(page: Int, text: String)]
```

### SwiftUI Sheet Patterns

**Use `sheet(item:)` instead of `sheet(isPresented:)` when passing data to sheets**. This avoids race conditions where the sheet opens before the state is updated:

```swift
// BAD: Can show blank content due to state race condition
@State private var selectedItem: Item?
@State private var showSheet = false

.sheet(isPresented: $showSheet) {
    if let item = selectedItem { ... }  // selectedItem may be nil
}

// GOOD: Item is passed directly when sheet opens
@State private var selectedItem: Item?

.sheet(item: $selectedItem) { item in
    DetailView(item: item)  // item is guaranteed non-nil
}
```

**Refresh the binding after async updates** to reflect changes in the sheet:

```swift
.sheet(item: $selectedItem) { item in
    DetailView(
        item: item,
        onUpdate: { newValue in
            Task {
                await viewModel.update(newValue)
                // Refresh selectedItem to update sheet content
                if let refreshed = viewModel.items.first(where: { $0.id == item.id }) {
                    selectedItem = refreshed
                }
            }
        }
    )
}
```

### SwiftUI List Tap Areas

**Use `contentShape(Rectangle())` to make entire row tappable** in List buttons:

```swift
Button(action: onTap) {
    HStack {
        // row content
    }
    .contentShape(Rectangle())  // Ensures full row responds to taps
}
.buttonStyle(.plain)
```

## Key Technologies

- **SwiftUI** - Primary UI framework
- **PDFKit** - PDF rendering and interaction (via UIViewRepresentable)
- **Vision** - OCR for scanned PDFs (VNRecognizeTextRequest)
- **GRDB** - SQLite database with type-safe queries

## Conventions

- Services are singletons accessed via `.shared`
- Models use `var id: Int64?` for auto-increment primary keys
- Errors are enums conforming to `LocalizedError` (e.g., `BookServiceError`, `PDFServiceError`)
- Views in Modules are organized by feature (Library, Reader)
- ViewModels use `@MainActor` and `@Observable`/`ObservableObject`
- Use `Task {}` for async work in view lifecycle

## Known TODOs

Some features are stubbed or need improvement:
- `AppState.setupServices()` - Service initialization
- Mixed state management in LibraryView (Combine + async/await) - consider unifying
- ViewModel tests disabled due to Swift 6 @MainActor deallocation issues

## Completed Features

- **Phase 1**: PDF import, library display, reading progress persistence
- **Phase 2**: Highlight creation (5 colors), highlight rendering (PDFAnnotation), highlight management (list, edit, delete), notes

## Logging

Use `Logger.shared` for all logging:

```swift
Logger.shared.debug("Detailed info for debugging")
Logger.shared.info("General information")
Logger.shared.warning("Non-critical issues")
Logger.shared.error("Critical errors")
```

Logs include file name, line number, and function name automatically.
