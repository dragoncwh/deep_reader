# DeepReader 代码优化报告

**日期**: 2026-01-28
**分析范围**: 全部生产代码 (约 797 行)

---

## 概述

本报告基于对 DeepReader iOS 代码库的全面分析，识别出架构、性能、代码质量等方面的优化机会，并按优先级提供改进建议。

---

## 高优先级问题

### 1. 同步文本提取阻塞导入流程

**文件**: `Core/PDF/PDFService.swift`
**行号**: 48-60
**问题**: `extractAllText` 方法同步遍历所有页面提取文本，大 PDF (如 1000 页) 会阻塞导入流程，无进度反馈。

**当前代码**:
```swift
for i in 0..<document.pageCount {
    if let page = document.page(at: i),
       let text = page.string {
        results.append((page: i, text: text))
    }
}
```

**建议方案**:
```swift
func extractText(
    from document: PDFDocument,
    batchSize: Int = 50,
    progress: @escaping (Int, Int) -> Void
) async -> [(page: Int, text: String)] {
    var results: [(page: Int, text: String)] = []
    let pageCount = document.pageCount

    for i in 0..<pageCount {
        if let page = document.page(at: i),
           let text = page.string {
            results.append((page: i, text: text))
        }

        if i % batchSize == 0 {
            progress(i, pageCount)
            await Task.yield() // 让出 CPU，避免阻塞
        }
    }
    return results
}
```

---

### 2. 书架封面无缓存，重复磁盘 I/O

**文件**: `Modules/Library/Views/LibraryView.swift`
**行号**: 169-177
**问题**: 每个 `BookCardView` 独立从磁盘加载封面图片，滚动时产生大量重复 I/O。

**建议方案**:
```swift
// 在 LibraryViewModel 中添加缓存
@MainActor
class LibraryViewModel: ObservableObject {
    private let coverCache = NSCache<NSString, UIImage>()

    func loadCoverImage(for book: Book) async -> UIImage? {
        guard let coverPath = book.coverPath else { return nil }

        // 检查缓存
        if let cached = coverCache.object(forKey: coverPath as NSString) {
            return cached
        }

        // 从磁盘加载
        return await Task.detached(priority: .background) {
            guard let image = UIImage(contentsOfFile: coverPath) else {
                return nil
            }
            await MainActor.run {
                self.coverCache.setObject(image, forKey: coverPath as NSString)
            }
            return image
        }.value
    }
}
```

---

### 3. 静默错误处理 (try?)

**文件**: `Core/Storage/BookService.swift`
**行号**: 28, 49, 80, 85, 133, 137
**问题**: 大量使用 `try?` 吞掉错误，导致：
- 封面生成失败无提示
- 文件删除失败留下孤立文件
- 调试困难

**当前代码**:
```swift
try? FileManager.default.removeItem(at: coverURL)
try? FileManager.default.removeItem(at: pdfURL)
```

**建议方案**:
```swift
// 1. 添加日志服务
enum LogLevel { case debug, info, warning, error }

class Logger {
    static let shared = Logger()

    func log(_ level: LogLevel, _ message: String, file: String = #file) {
        #if DEBUG
        print("[\(level)] \(message)")
        #endif
        // 生产环境可接入 OSLog 或第三方服务
    }
}

// 2. 替换静默错误
do {
    try FileManager.default.removeItem(at: coverURL)
} catch {
    Logger.shared.log(.warning, "Failed to delete cover: \(error.localizedDescription)")
}
```

---

### 4. 混合状态管理模式

**文件**: `Modules/Library/Views/LibraryView.swift`
**行号**: 186-196
**问题**: 同时使用 Combine (NotificationCenter + @Published) 和 async/await，增加维护复杂度。

**当前代码**:
```swift
NotificationCenter.default.publisher(for: .bookImported)
    .sink { [weak self] _ in
        Task { await self?.loadBooks() }
    }
    .store(in: &cancellables)
```

**建议方案**: 统一使用 async/await + @Observable (iOS 17+) 或保持 Combine 但移除混用：

```swift
// 方案 A: 纯 async/await (推荐)
// 在 ContentView 导入成功后直接调用 viewModel.loadBooks()

// 方案 B: 保持 Combine 但简化
// 移除 NotificationCenter，改用 @EnvironmentObject 共享状态
```

---

### 5. ViewModel 测试被禁用

**文件**: `DeepReaderTests/ViewModelTests.swift`
**行号**: 6-8
**问题**: 因 Swift 6 严格并发模式下的 `@MainActor` 释放问题，测试被禁用。

**建议方案**:
```swift
// 修复方案: 将业务逻辑抽取到可测试的 Service 层
// ViewModel 只负责状态管理，Service 负责业务逻辑

protocol BookLoadingService: Sendable {
    func fetchAllBooks() async throws -> [Book]
}

// Service 可以轻松测试，不依赖 @MainActor
```

---

## 中优先级问题

### 6. 防抖保存无取消机制

**文件**: `Modules/Reader/Views/ReaderView.swift`
**行号**: 288-298
**问题**: 页面变化防抖 1 秒后保存进度，但视图消失时未取消待处理的保存。

**建议方案**:
```swift
private var saveProgressCancellable: AnyCancellable?

func setupPageChangeObserver() {
    saveProgressCancellable = $currentPage
        .debounce(for: .seconds(1), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            Task { await self?.saveProgress() }
        }
}

func cleanup() {
    saveProgressCancellable?.cancel()
    saveProgressCancellable = nil
}
```

---

### 7. 搜索结果无分页

**文件**: `Modules/Reader/Views/ReaderView.swift`
**行号**: 158-174
**问题**: `List(viewModel.searchResults)` 一次性渲染所有结果，大量匹配时 UI 卡顿。

**建议方案**:
```swift
// 限制显示数量 + 加载更多
@State private var displayLimit = 50

List(viewModel.searchResults.prefix(displayLimit), id: \.self) { result in
    // ...
}

if viewModel.searchResults.count > displayLimit {
    Button("加载更多 (\(viewModel.searchResults.count - displayLimit) 条)") {
        displayLimit += 50
    }
}
```

---

### 8. 数据库批量插入效率低

**文件**: `Core/Storage/DatabaseService.swift`
**行号**: 209-218
**问题**: 循环执行单条 INSERT，大 PDF 索引慢。

**当前代码**:
```swift
for (pageNumber, text) in pages {
    try db.execute(sql: "INSERT INTO text_content ...", arguments: [...])
}
```

**建议方案**:
```swift
// 使用 GRDB 批量插入
try TextContent.insertAll(db, pages.map { pageNumber, text in
    TextContent(bookId: bookId, pageNumber: pageNumber, content: text)
})
```

---

### 9. FTS5 搜索无排名

**文件**: `Core/Storage/DatabaseService.swift`
**行号**: 115-121
**问题**: 简单 FTS5 匹配，无相关性排序。

**建议方案**:
```sql
-- 添加 bm25 排名
SELECT *, bm25(text_content_fts, 2.0, 4.0) as rank
FROM text_content_fts
WHERE text_content_fts MATCH ?
ORDER BY rank
```

---

### 10. 未使用的属性 (死代码)

**文件**: `Modules/Reader/Views/ReaderView.swift`
**行号**: 275
**问题**: `private weak var pdfView: PDFView?` 定义但未使用。

**建议**: 直接删除。

---

## 低优先级问题

| 问题 | 文件 | 说明 |
|------|------|------|
| NotificationCenter 观察者泄漏风险 | ReaderView.swift:98-102 | 建议用 Combine 替代 |
| 无内存缓存策略 | PDFService.swift | 封面重复生成 |
| 孤立文件无清理 | BookService.swift | 删除失败后文件残留 |
| Force unwrap 风险 | ReaderView.swift:304-308 | PDF 文件可能被删除 |

---

## 建议执行顺序

| 优先级 | 任务 | 预期收益 |
|--------|------|----------|
| 1 | 修复静默错误处理 | 提升可调试性 |
| 2 | 添加封面图片缓存 | 立即改善书架滚动体验 |
| 3 | 文本提取分批 + 进度 | 改善大 PDF 导入体验 |
| 4 | 统一状态管理模式 | 降低维护成本 |
| 5 | 启用 ViewModel 测试 | 提升代码质量保障 |
| 6 | 搜索结果分页 | 改善搜索体验 |
| 7 | 数据库批量插入 | 提升索引性能 |

---

## 总结

本代码库整体架构清晰，遵循 MVVM 模式。主要问题集中在：

1. **性能**: 大文件处理缺乏优化 (文本提取、图片缓存)
2. **错误处理**: 过度使用 `try?` 导致问题隐藏
3. **可测试性**: ViewModel 测试被禁用

建议先完成 Phase 1 功能连接，再逐步优化上述问题。
