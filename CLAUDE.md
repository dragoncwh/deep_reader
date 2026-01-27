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

## Architecture

### Pattern: MVVM with Singleton Services

```
DeepReader/
├── App/                    # App entry point, ContentView
├── Models/                 # GRDB-backed data models (Book, Highlight)
├── Modules/
│   ├── Library/Views/      # Book library UI
│   └── Reader/Views/       # PDF reader UI
├── Core/
│   ├── Storage/            # DatabaseService, BookService
│   └── PDF/                # PDFService (PDFKit + Vision OCR)
└── Shared/DesignSystem/    # Typography, Spacing, Colors, Components
```

### Key Services (Singletons)

- `DatabaseService.shared` - SQLite via GRDB, handles migrations
- `PDFService.shared` - PDF loading, text extraction, OCR, cover generation
- `BookService.shared` - Book CRUD operations

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
    // ... fields

    static let databaseTableName = "books"

    enum Columns: String, ColumnExpression {
        case id, title, author // ...
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

### Security-Scoped Resources

Always wrap file access for user-selected PDFs:

```swift
let accessing = url.startAccessingSecurityScopedResource()
defer {
    if accessing {
        url.stopAccessingSecurityScopedResource()
    }
}
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

## Key Technologies

- **SwiftUI** - Primary UI framework
- **PDFKit** - PDF rendering and interaction (via UIViewRepresentable)
- **Vision** - OCR for scanned PDFs (VNRecognizeTextRequest)
- **GRDB** - SQLite database with type-safe queries

## Conventions

- Services are singletons accessed via `.shared`
- Models use `var id: Int64?` for auto-increment primary keys
- Errors are enums conforming to `LocalizedError`
- Views in Modules are organized by feature (Library, Reader)
