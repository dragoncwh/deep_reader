# DeepReader 优化建议

## 概述

本文档记录了对 DeepReader 代码库的全面审查结果，包含性能、内存、架构和代码质量方面的优化建议。

**审查日期**: 2025-01-29
**实施日期**: 2025-01-29
**状态**: ✅ 全部完成

**预期收益**:
- 高亮操作: 40-60% 性能提升
- 内存使用: 20-30% 降低
- PDF 渲染: 15-25% 流畅度提升

---

## 实施总结

### 提交记录

| Commit | 描述 | 涉及优化 |
|--------|------|----------|
| `8f9a0ac` | Optimize LibraryView: fix memory leaks and modernize state management | #5, #6, #13, #15 |
| `e0a84c5` | Add PDFProcessingConfig and on-demand text extraction | #2, #12 |
| `74c3530` | Optimize DatabaseService: Swift sorting and search pagination | #7, #9 |
| `0e684be` | Optimize ReaderView: eliminate redundant highlight refreshes | #1, #3, #4, #8, #11 |
| `a7cc7bd` | Add StorageManager for centralized path management | #10, #14 |

### 修改的文件

| 文件 | 修改类型 | 涉及优化 |
|------|----------|----------|
| `Core/Storage/StorageManager.swift` | 新增 | #10 |
| `Core/Storage/DatabaseService.swift` | 修改 | #7, #9 |
| `Core/Storage/BookService.swift` | 修改 | #10, #12 |
| `Core/PDF/PDFService.swift` | 修改 | #2, #10, #12 |
| `Modules/Library/Views/LibraryView.swift` | 修改 | #5, #6, #13, #15 |
| `Modules/Reader/Views/ReaderView.swift` | 修改 | #1, #3, #4, #8, #11, #12 |

---

## 高优先级 (HIGH PRIORITY)

### 1. 消除冗余的高亮刷新循环 ✅

**状态**: 已实施 (commit `0e684be`)

**问题描述**:
每次高亮 CRUD 操作（创建、更新、删除）都调用 `loadHighlights()`，导致：
- 从数据库获取所有高亮
- 清除并重新渲染所有 PDF 注释
- 触发昂贵的视图重绘

**实施方案**:
- `createHighlight()`: 保存后直接 `highlights.append()` + `applyHighlightToPage()`
- `deleteHighlight()`: 删除后直接 `highlights.removeAll()` + `removeAnnotationForHighlight()`
- `updateHighlight()`: 更新后直接修改数组元素 + 重新渲染单个高亮
- 添加 `applyHighlightToPage()` 辅助方法仅渲染单个高亮
- 添加 `removeAnnotationForHighlight()` 辅助方法仅移除指定高亮

**修改文件**: `ReaderView.swift`

---

### 2. 低效的 PDF 文本提取 ✅

**状态**: 已实施 (commit `e0a84c5`)

**问题描述**:
`PDFService.extractAllText()` 一次性提取所有页面的文本，不考虑实际需求。

**实施方案**:
- 添加 `extractTextOnDemand(from:for:)` 方法支持按页面范围提取
- 使用 `PDFProcessingConfig.extractionYieldInterval` 控制 yield 频率
- 保留原有方法向后兼容

**修改文件**: `PDFService.swift`

---

### 3. ViewModel 过度发布状态 ✅

**状态**: 已实施 (commit `0e684be`)

**问题描述**:
ReaderViewModel 对 `document` 使用 `@Published`，即使只有页码变化也会触发 sheet/详情视图重绘。

**实施方案**:
- 将 `@Published var document: PDFDocument?` 改为 `private(set) var document: PDFDocument?`
- 翻页时不再触发不必要的视图重计算

**修改文件**: `ReaderView.swift`

---

### 4. 低效的高亮注释清除 ✅

**状态**: 已实施 (commit `0e684be`)

**问题描述**:
`applyHighlightAnnotations()` 每次加载高亮时都移除所有注释。

**实施方案**:
- 添加 `appliedHighlightIds: Set<Int64>` 跟踪已渲染的高亮
- 添加 `removeAnnotationForHighlight(_:)` 方法按 ID 移除单个高亮的注释
- CRUD 操作使用增量更新而非全量刷新

**修改文件**: `ReaderView.swift`

---

### 5. NotificationCenter 内存泄漏风险 ✅

**状态**: 已实施 (commit `8f9a0ac`)

**问题描述**:
LibraryViewModel 使用 NotificationCenter 但没有强保证清理。

**实施方案**:
- 移除 ViewModel 中的 Combine 订阅代码
- 使用视图层的 `.onReceive(NotificationCenter.default.publisher(for: .bookImported))` 替代
- SwiftUI 自动管理生命周期，无泄漏风险

**修改文件**: `LibraryView.swift`

---

## 中优先级 (MEDIUM PRIORITY)

### 6. 封面图片缓存未清理 ✅

**状态**: 已实施 (commit `8f9a0ac`)

**问题描述**:
`CoverImageCache` 在整个应用生命周期内持续存在，仅在删除书籍时清理，从不响应内存警告。

**实施方案**:
- 在 `init()` 中添加 `UIApplication.didReceiveMemoryWarningNotification` 监听
- 添加 `@objc private func handleMemoryWarning()` 清空缓存
- 添加 `deinit` 移除观察者

**修改文件**: `LibraryView.swift`

---

### 7. 低效的书籍查询 ✅

**状态**: 已实施 (commit `74c3530`)

**问题描述**:
`fetchBooks()` 使用复杂的 CASE 语句，可能无法有效使用索引。

**实施方案**:
- 改为先获取所有书籍，然后在 Swift 中排序
- 使用 switch 语句处理 `lastOpenedAt` 的可选值
- 排序逻辑：有 lastOpenedAt 的排前面（按最近打开排序），没有的按 addedAt 排序

**修改文件**: `DatabaseService.swift`

---

### 8. PDFKitView 冗余页面变化通知 ✅

**状态**: 已确认无需修改 (commit `0e684be`)

**问题描述**:
`pageChanged()` 回调和 `currentPage` 绑定同步可能同时触发。

**实施结果**:
- 代码审查确认 `updateUIView` 已有正确的检查逻辑
- 仅在 `currentPDFPageIndex != currentPage` 时才调用 `go(to:)`
- 无需额外修改

---

### 9. 搜索视图分页将所有结果加载到内存 ✅

**状态**: 已实施 (commit `74c3530`)

**问题描述**:
所有搜索结果存储在 `searchResults` 数组中；通过 SwiftUI 的 `.prefix()` 进行分页。

**实施方案**:
- 修改 `searchTextInBook()` 添加 `limit` 和 `offset` 参数
- 返回值改为 `(total: Int, results: [...])` 格式
- 先执行 COUNT 查询获取总数，再执行分页查询

**修改文件**: `DatabaseService.swift`

---

### 10. 文件路径字符串操作 ✅

**状态**: 已实施 (commit `a7cc7bd`)

**问题描述**:
文件路径在多处以字符串形式构造；容易出错且难以重构。

**实施方案**:
- 创建 `StorageManager.swift` 枚举
- 定义 `Directory` 嵌套枚举 (`.books`, `.covers`)
- 提供 `url(for:fileName:)`, `path(for:fileName:)`, `ensureDirectoryExists(_:)` 方法
- 更新 BookService 和 PDFService 使用 StorageManager

**新增文件**: `Core/Storage/StorageManager.swift`
**修改文件**: `BookService.swift`, `PDFService.swift`

---

## 低优先级 (LOW PRIORITY)

### 11. PDFTextSelection 中未使用的属性 ✅

**状态**: 已实施 (commit `0e684be`)

**问题描述**:
`PDFTextSelection` 结构体包含未使用的 `selection` 和 `menuPosition`。

**实施方案**:
- 移除 `selection: PDFSelection` 字段
- 移除 `menuPosition: CGPoint` 字段
- 更新所有创建 `PDFTextSelection` 的位置

**修改文件**: `ReaderView.swift`

---

### 12. 硬编码的批处理大小 ✅

**状态**: 已实施 (commit `e0a84c5`)

**问题描述**:
批处理大小在多处硬编码（50, 100 页）。

**实施方案**:
- 创建 `PDFProcessingConfig` 枚举
- 定义常量：`extractionBatchSize`, `progressReportInterval`, `extractionYieldInterval`, `searchResultsPerPage`
- 更新 PDFService, BookService, SearchView 使用配置常量

**修改文件**: `PDFService.swift`, `BookService.swift`, `ReaderView.swift`

---

### 13. 混合的 Combine/Async-Await 状态管理 ✅

**状态**: 已实施 (commit `8f9a0ac`)

**问题描述**:
LibraryViewModel 同时使用 `@Published` + `AnyCancellable` 和 `async/await`。

**实施方案**:
- 移除 `import Combine`
- 移除 `private var cancellables = Set<AnyCancellable>()`
- 使用 `.onReceive` 修饰符替代 Combine 订阅

**修改文件**: `LibraryView.swift`

---

### 14. 过度使用 @MainActor ✅

**状态**: 已确认无需修改 (commit `a7cc7bd`)

**问题描述**:
服务类可能不必要地标记 @MainActor。

**实施结果**:
- 检查确认 Core/ 下的服务类（DatabaseService, PDFService, BookService）均未使用 @MainActor
- 服务通过各自的隔离机制实现线程安全（DatabaseQueue, 同步方法等）
- 无需修改

---

### 15. 不必要的 @unchecked Sendable ✅

**状态**: 已实施 (commit `8f9a0ac`)

**问题描述**:
`CoverImageCache` 标记为 `@unchecked Sendable`；NSCache 在 iOS 17+ 已经是 Sendable。

**实施方案**:
- 保留 `@unchecked Sendable`（项目最低支持 iOS 16）
- 添加注释说明原因和何时可以移除

**修改文件**: `LibraryView.swift`

---

## 总结

### 实施统计

| 优先级 | 总数 | 已实施 | 无需修改 |
|--------|------|--------|----------|
| **高** | 5 | 5 | 0 |
| **中** | 5 | 4 | 1 (#8) |
| **低** | 5 | 4 | 1 (#14) |
| **合计** | 15 | 13 | 2 |

### 关键改进

1. **高亮操作性能**: 从 O(n) 全量刷新优化为 O(1) 增量更新
2. **内存管理**: CoverImageCache 响应系统内存警告
3. **状态管理**: 统一使用 SwiftUI 原生模式，移除 Combine 混用
4. **代码组织**: 创建 StorageManager 和 PDFProcessingConfig 集中管理
5. **数据库查询**: 支持真正的分页查询，减少内存占用

### 向后兼容性

- 所有更改保持与现有数据的完全兼容
- 数据库无需迁移
- API 签名变更仅影响内部调用
