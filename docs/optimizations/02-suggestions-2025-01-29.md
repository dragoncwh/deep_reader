# DeepReader 优化建议

## 概述

本文档记录了对 DeepReader 代码库的全面审查结果，包含性能、内存、架构和代码质量方面的优化建议。

**审查日期**: 2025-01-29

**预期收益**:
- 高亮操作: 40-60% 性能提升
- 内存使用: 20-30% 降低
- PDF 渲染: 15-25% 流畅度提升

---

## 高优先级 (HIGH PRIORITY)

### 1. 消除冗余的高亮刷新循环

**问题描述**:
每次高亮 CRUD 操作（创建、更新、删除）都调用 `loadHighlights()`，导致：
- 从数据库获取所有高亮
- 清除并重新渲染所有 PDF 注释
- 触发昂贵的视图重绘

**影响位置**: `ReaderView.swift` - ReaderViewModel (lines 892, 907, 921)

**性能影响**: 创建/编辑/删除多个高亮会导致级联的数据库查询和 PDF 渲染

**建议方案**:
不再执行全量刷新，而是直接更新本地 `highlights` 数组，仅更新受影响的注释：

```swift
// 当前实现（低效）:
func createHighlight(...) async {
    // ...保存到数据库...
    await loadHighlights()  // 重新获取所有高亮并重绘
}

// 优化后:
func createHighlight(...) async {
    let boundsData = try JSONEncoder().encode(bounds)
    var highlight = Highlight(...)
    try DatabaseService.shared.saveHighlight(&highlight)

    // 本地添加，不重新获取
    highlights.append(highlight)
    applyHighlightToPage(highlight)  // 仅更新当前页
}

private func applyHighlightToPage(_ highlight: Highlight) {
    guard let document = document,
          let page = document.page(at: highlight.pageNumber) else { return }

    for rect in highlight.bounds {
        let annotation = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
        annotation.color = highlight.color.uiColor.withAlphaComponent(0.4)
        annotation.setValue(highlight.id, forAnnotationKey: PDFAnnotationKey(rawValue: "highlightId"))
        page.addAnnotation(annotation)
    }
}
```

---

### 2. 低效的 PDF 文本提取

**问题描述**:
`PDFService.extractAllText()` 一次性提取所有页面的文本，不考虑实际需求。

**影响位置**:
- `PDFService.swift` (lines 57-80)
- `BookService.swift` (line 127)

**性能影响**:
- 大型 PDF 导入时内存峰值
- 文本索引期间阻塞 UI（即使在后台 Task 中运行）
- 无法取消超大书籍的部分提取

**建议方案**:
实现懒加载/按需文本提取：

```swift
/// 仅提取指定页面范围的文本
func extractTextOnDemand(
    from document: PDFDocument,
    for pageRange: Range<Int>
) async -> [(page: Int, text: String)] {
    var results: [(page: Int, text: String)] = []

    for i in pageRange {
        if let page = document.page(at: i),
           let text = page.string,
           !text.isEmpty {
            results.append((page: i, text: text))

            // 每 5 页让出控制权，防止内存堆积
            if i % 5 == 0 {
                await Task.yield()
            }
        }
    }
    return results
}
```

同时为 `BookService.indexTextContent()` 添加取消令牌，允许用户导入大型 PDF 而不必完成全量索引。

---

### 3. ViewModel 过度发布状态

**问题描述**:
ReaderViewModel 对 `document` 使用 `@Published`，即使只有页码变化也会触发 sheet/详情视图重绘。

**影响位置**: `ReaderView.swift`, line 704

**性能影响**: 每次翻页都会因 `@Published var document` 导致不必要的视图重计算

**建议方案**:
对文档引用使用非发布的状态：

```swift
@MainActor
final class ReaderViewModel: ObservableObject {
    let book: Book

    // 保持可观察的初始加载/状态
    @Published var pageCount: Int = 0
    @Published var currentPage: Int = 0
    @Published var searchResults: [PDFSelection] = []
    @Published var isLoading = false
    @Published var highlights: [Highlight] = []

    // 非发布的文档引用（不触发重计算）
    private(set) var document: PDFDocument?

    func loadDocument() async {
        // ... 加载逻辑 ...
        self.document = PDFDocument(url: url)
        self.pageCount = document?.pageCount ?? 0
        await loadHighlights()
    }
}
```

---

### 4. 低效的高亮注释清除

**问题描述**:
`applyHighlightAnnotations()` 每次加载高亮时都移除所有注释。

**影响位置**: `ReaderView.swift`, lines 791-797

**性能影响**: 对于页数多的 PDF 操作昂贵；每次高亮变化都会调用

**建议方案**:
跟踪已应用的高亮，仅移除变化的部分：

```swift
private var appliedHighlightIds: Set<Int64> = []

func applyHighlightAnnotations() {
    guard let document = document else { return }

    let currentIds = Set(highlights.compactMap { $0.id })
    let toRemove = appliedHighlightIds.subtracting(currentIds)
    let toAdd = currentIds.subtracting(appliedHighlightIds)

    // 仅移除变化的高亮
    for highlightId in toRemove {
        removeAnnotationForHighlight(highlightId, from: document)
    }

    // 仅添加新高亮
    for highlight in highlights where toAdd.contains(highlight.id ?? 0) {
        applyHighlightToPage(highlight)
    }

    appliedHighlightIds = currentIds
}
```

---

### 5. NotificationCenter 内存泄漏风险

**问题描述**:
LibraryViewModel 使用 NotificationCenter 但没有强保证清理。

**影响位置**: `LibraryView.swift`, lines 225-232

**性能影响**: 如果 ViewModel 在未清理的情况下被释放，观察者仍保持注册状态

**建议方案**:
使用 `onReceive` 修饰符或实现显式清理：

```swift
// 方案 1: 在 ViewModel 中添加 deinit
@MainActor
final class LibraryViewModel: ObservableObject {
    // ... 现有代码 ...

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// 方案 2: 在视图中使用 onReceive
.onReceive(
    NotificationCenter.default.publisher(for: .bookImported),
    perform: { _ in
        Task {
            await viewModel.loadBooks()
        }
    }
)
```

---

## 中优先级 (MEDIUM PRIORITY)

### 6. 封面图片缓存未清理

**问题描述**:
`CoverImageCache` 在整个应用生命周期内持续存在，限制 50 张图片，但书库可能有数百本书。

**影响位置**: `LibraryView.swift`, line 221, line 250

**问题**: 仅在删除书籍时清理，从不响应内存警告

**建议方案**:
添加内存压力处理：

```swift
final class CoverImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 50

        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

---

### 7. 低效的书籍查询

**问题描述**:
`fetchBooks()` 使用复杂的 CASE 语句，可能无法有效使用索引。

**影响位置**: `DatabaseService.swift`, lines 149-154

```swift
// 当前实现
try Book
    .order(sql: "CASE WHEN lastOpenedAt IS NULL THEN 1 ELSE 0 END, lastOpenedAt DESC, addedAt DESC")
    .fetchAll(db)
```

**建议方案**:

```swift
// 方案 1: 在 Swift 中排序（适合小数据集）
func fetchBooks() throws -> [Book] {
    try queue().read { db in
        try Book.fetchAll(db)
    }
    .sorted { a, b in
        let aDate = a.lastOpenedAt ?? .distantPast
        let bDate = b.lastOpenedAt ?? .distantPast
        return aDate > bDate
    }
}

// 方案 2: 为大型书库添加索引
migrator.registerMigration("v4_reading_order_index") { db in
    try db.create(index: "idx_books_reading_order",
                  on: "books",
                  columns: ["lastOpenedAt", "addedAt"])
}
```

---

### 8. PDFKitView 冗余页面变化通知

**问题描述**:
`pageChanged()` 回调和 `currentPage` 绑定同步可能同时触发。

**影响位置**: `ReaderView.swift`, lines 409-416 和 358-372

**问题**: 从通知更新 `currentPage` → 触发 `updateUIView` → 可能再次调用 `pdfView.go(to:)`

**建议方案**:
使用单一数据源并添加防抖：

```swift
func updateUIView(_ pdfView: PDFView, context: Context) {
    // 仅在有意义的差异时同步
    if pdfView.document !== document {
        pdfView.document = document
        if let page = document?.page(at: currentPage) {
            pdfView.go(to: page)
        }
    } else {
        // 检查是否需要导航（避免冗余调用）
        if let currentPDFPage = pdfView.currentPage,
           let index = pdfView.document?.index(for: currentPDFPage),
           index != currentPage,
           let targetPage = pdfView.document?.page(at: currentPage) {
            pdfView.go(to: targetPage)
        }
    }
}
```

---

### 9. 搜索视图分页将所有结果加载到内存

**问题描述**:
所有搜索结果存储在 `searchResults` 数组中；通过 SwiftUI 的 `.prefix()` 进行分页。

**影响位置**: `ReaderView.swift`, lines 824-831, 519-521

**性能影响**: 包含常见搜索词的大型文档可能将数千个结果加载到内存中

**建议方案**:
在 DatabaseService 中实现真正的数据库级分页：

```swift
func searchTextInBook(
    bookId: Int64,
    query: String,
    limit: Int = 50,
    offset: Int = 0
) throws -> (total: Int, results: [(pageNumber: Int, snippet: String)]) {
    guard !query.isEmpty else { return (0, []) }

    return try queue().read { db in
        // 获取总数
        let totalRow = try Row.fetchOne(db, sql: """
            SELECT COUNT(*) as count FROM text_content_fts
            JOIN text_content tc ON tc.id = text_content_fts.rowid
            WHERE text_content_fts MATCH ? AND tc.bookId = ?
        """, arguments: [query, bookId])
        let total = (totalRow?["count"] as? Int) ?? 0

        // 获取分页结果
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                tc.pageNumber,
                snippet(text_content_fts, 0, '<b>', '</b>', '...', 32) as snippet
            FROM text_content_fts
            JOIN text_content tc ON tc.id = text_content_fts.rowid
            WHERE text_content_fts MATCH ? AND tc.bookId = ?
            ORDER BY tc.pageNumber
            LIMIT ? OFFSET ?
        """, arguments: [query, bookId, limit, offset])

        return (total, rows.map { row in
            (
                pageNumber: row["pageNumber"] as Int,
                snippet: row["snippet"] as String
            )
        })
    }
}
```

---

### 10. 文件路径字符串操作

**问题描述**:
文件路径在多处以字符串形式构造；容易出错且难以重构。

**影响位置**: `BookService.swift`, `PDFService.swift`, `DatabaseService.swift`

**建议方案**:
创建存储管理抽象：

```swift
struct StorageManager {
    enum Directory {
        case books
        case covers
        case database

        var url: URL {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            switch self {
            case .books: return docs.appendingPathComponent("Books", isDirectory: true)
            case .covers: return docs.appendingPathComponent("Covers", isDirectory: true)
            case .database: return docs.appendingPathComponent("Database", isDirectory: true)
            }
        }
    }

    static func url(for directory: Directory, fileName: String) -> URL {
        directory.url.appendingPathComponent(fileName)
    }

    static func path(for directory: Directory, fileName: String) -> String {
        url(for: directory, fileName: fileName).path
    }

    static func ensureDirectoryExists(_ directory: Directory) throws {
        try FileManager.default.createDirectory(
            at: directory.url,
            withIntermediateDirectories: true
        )
    }
}
```

---

## 低优先级 (LOW PRIORITY)

### 11. PDFTextSelection 中未使用的属性

**问题描述**:
`PDFTextSelection` 结构体包含未使用的 `selection` 和 `menuPosition`。

**影响位置**: `ReaderView.swift`, lines 202-210

**建议方案**:
移除未使用的字段：

```swift
struct PDFTextSelection {
    let text: String
    let page: PDFPage
    let pageIndex: Int
    let bounds: [CGRect]
    // 已移除: selection, menuPosition (未使用)
}
```

---

### 12. 硬编码的批处理大小

**问题描述**:
批处理大小在多处硬编码（50, 100 页）。

**影响位置**: `PDFService.swift` (50), `BookService.swift` (100)

**建议方案**:
创建配置常量：

```swift
enum PDFProcessingConfig {
    static let extractionBatchSize = 50
    static let progressReportInterval = 100
    static let extractionYieldInterval = 5
    static let searchResultsPerPage = 50
}
```

---

### 13. 混合的 Combine/Async-Await 状态管理

**问题描述**:
LibraryViewModel 同时使用 `@Published` + `AnyCancellable` 和 `async/await`。

**影响位置**: `LibraryView.swift`, line 13

**建议方案**:
迁移到纯 async/await：

```swift
// 移除: private var cancellables = Set<AnyCancellable>()
// 使用 AsyncSequence 替换通知订阅:

.task {
    for await _ in NotificationCenter.default.notifications(named: .bookImported) {
        await viewModel.loadBooks()
    }
}
```

---

### 14. 过度使用 @MainActor

**问题描述**:
服务类不必要地标记 @MainActor（DatabaseService, PDFService 不需要主线程）。

**影响位置**: DatabaseService, PDFService

**建议方案**:
仅 ViewModels 和 Views 使用 @MainActor；服务应该是线程安全的：

```swift
// 服务类应该是 nonisolated 的
nonisolated final class DatabaseService {
    static let shared = DatabaseService()

    nonisolated private init() {}

    // 无需 @MainActor - 通过 dbQueue 隔离实现线程安全
    func fetchBooks() throws -> [Book] { ... }
}
```

---

### 15. 不必要的 @unchecked Sendable

**问题描述**:
`CoverImageCache` 标记为 `@unchecked Sendable`；NSCache 在 iOS 17+ 已经是 Sendable。

**影响位置**: `LibraryView.swift`, line 194

**建议方案**:
移除 @unchecked 以提高清晰度，或添加编译条件：

```swift
#if swift(>=5.9)
final class CoverImageCache: Sendable {
#else
final class CoverImageCache: @unchecked Sendable {
#endif
    private let cache = NSCache<NSString, UIImage>()
    // ...
}
```

---

## 总结

### 按影响分类

| 优先级 | 数量 | 涉及领域 |
|--------|------|----------|
| **高** | 5 | 性能（高亮刷新、PDF 提取）、状态管理、内存 |
| **中** | 5 | 查询优化、缓存管理、视图同步 |
| **低** | 5 | 代码质量、可维护性、配置 |

### 建议实施顺序

1. **修复高亮 CRUD 刷新** - 最大的用户体验影响
2. **实现懒加载文本提取** - 防止大型 PDF 的内存问题
3. **优化 PDF 注释清除** - 流畅的翻页体验
4. **添加缓存内存压力处理** - 稳定性
5. **改进书籍查询** - 书库加载速度

### 实施注意事项

- 所有更改都应保持与现有数据的向后兼容性
- 建议逐个实施并测试，而非一次性全部更改
- 高优先级项目可独立实施，无相互依赖
