# Phase 3: 全局搜索 - 任务拆解

## 状态: 待开发

## 目标
让用户可以 **跨书籍搜索内容 → 查看匹配结果 → 跳转到原文位置**，并支持扫描件 OCR 索引

---

## 现有基础

### 已完成的基础设施
- **DatabaseService** (`Core/Storage/DatabaseService.swift`)
  - `text_content` 表存储书籍文本（按页）
  - `text_content_fts` FTS5 虚拟表（全文索引）
  - `searchText(query:)` - 跨书籍搜索，支持 bm25 排序
  - `searchTextInBook(bookId:query:)` - 单书搜索
  - `storeTextContent(bookId:pages:)` - 批量存储文本
- **PDFService** (`Core/PDF/PDFService.swift`)
  - `performOCR(on:scale:)` - 单页 OCR（Vision 框架）
  - `extractAllText(from:batchSize:progress:)` - 批量文本提取（带进度）
- **ReaderView** - 已有单文档内搜索 UI（`SearchView`）

### 需要新增
- 书架页全局搜索栏
- 全局搜索结果视图
- OCR 检测与触发逻辑
- OCR 进度显示

---

## 3.1 全局搜索 UI

### Task 3.1.1: 在书架页添加搜索栏
**文件**: `Modules/Library/Views/LibraryView.swift`
**描述**: 在书架顶部添加搜索输入框
**验收标准**:
- [ ] 添加 `@State var searchText: String` 状态
- [ ] 使用 `.searchable(text:)` modifier 添加搜索栏
- [ ] 搜索栏支持中英文输入
- [ ] 搜索时显示搜索结果视图，隐藏书架网格
- [ ] 清空搜索时恢复书架显示

### Task 3.1.2: 创建全局搜索结果视图
**文件**: `Modules/Search/Views/GlobalSearchResultsView.swift` (新建)
**描述**: 显示跨书籍搜索结果列表
**验收标准**:
- [ ] 创建 `GlobalSearchResultsView` 组件
- [ ] 接收搜索关键词，调用 `DatabaseService.searchText()`
- [ ] 结果按相关性（bm25 score）排序
- [ ] 显示加载状态（搜索中）
- [ ] 空结果时显示友好提示

### Task 3.1.3: 创建搜索结果行组件
**文件**: `Modules/Search/Views/GlobalSearchResultRow.swift` (新建)
**描述**: 单条搜索结果的显示组件
**验收标准**:
- [ ] 显示书名（需关联 Book 表获取）
- [ ] 显示页码
- [ ] 显示匹配片段（snippet，高亮关键词）
- [ ] 使用 `DesignSystem` 样式规范
- [ ] 点击触发导航回调

### Task 3.1.4: 实现搜索结果数据模型
**文件**: `Models/SearchResult.swift` (新建)
**描述**: 封装搜索结果的数据结构
**验收标准**:
- [ ] 创建 `SearchResult` struct
- [ ] 包含字段: `bookId`, `bookTitle`, `pageNumber`, `snippet`, `rank`
- [ ] 实现 `Identifiable` 协议
- [ ] 在 `DatabaseService` 添加 `searchTextWithBookInfo()` 方法，联表查询

### Task 3.1.5: 实现搜索结果跳转
**文件**: `LibraryView.swift`, `GlobalSearchResultsView.swift`
**描述**: 点击搜索结果跳转到对应书籍和页面
**验收标准**:
- [ ] 点击结果打开对应书籍的 `ReaderView`
- [ ] 传递目标页码，打开后自动跳转
- [ ] 跳转后关闭搜索界面
- [ ] 考虑使用 `AppState.selectedBook` 和初始页码参数

### Task 3.1.6: 添加搜索防抖
**文件**: `LibraryView.swift` 或 `LibraryViewModel`
**描述**: 优化搜索性能，避免频繁查询
**验收标准**:
- [ ] 实现 300ms 防抖（debounce）
- [ ] 输入时取消上一次未完成的搜索
- [ ] 使用 `Task` + `Task.cancel()` 或 Combine

---

## 3.2 OCR 增强

### Task 3.2.1: 检测 PDF 是否为扫描件
**文件**: `Core/PDF/PDFService.swift`
**描述**: 判断 PDF 是否缺少文本层（纯图片）
**验收标准**:
- [ ] 添加 `isScannedPDF(_:samplePages:)` 方法
- [ ] 采样检查前 N 页（如前 5 页）
- [ ] 判断标准：页面 `.string` 为空或仅有极少字符
- [ ] 返回 `Bool` 表示是否需要 OCR

### Task 3.2.2: 在导入时检测并标记扫描件
**文件**: `Core/Storage/BookService.swift`, `Models/Book.swift`
**描述**: 导入 PDF 时检测是否为扫描件并保存状态
**验收标准**:
- [ ] 在 `Book` 模型添加 `needsOCR: Bool` 字段
- [ ] 添加数据库迁移（`v4_ocr_flag`）
- [ ] 在 `importPDF()` 中调用 `PDFService.isScannedPDF()`
- [ ] 保存检测结果到数据库

### Task 3.2.3: 创建 OCR 处理队列
**文件**: `Core/PDF/OCRService.swift` (新建)
**描述**: 管理 OCR 任务的后台处理
**验收标准**:
- [ ] 创建 `OCRService` 单例
- [ ] 支持添加书籍到 OCR 队列
- [ ] 后台逐页执行 OCR
- [ ] OCR 完成的文本存入 `text_content` 表
- [ ] 支持取消正在进行的 OCR

### Task 3.2.4: 实现 OCR 进度跟踪
**文件**: `Core/PDF/OCRService.swift`
**描述**: 跟踪并报告 OCR 处理进度
**验收标准**:
- [ ] 添加 `@Published var ocrProgress: [Int64: Double]` (bookId -> progress)
- [ ] 每处理一页更新进度
- [ ] OCR 完成后更新 `Book.needsOCR = false`
- [ ] 支持查询某书籍的 OCR 状态

### Task 3.2.5: 在书架显示 OCR 状态
**文件**: `Modules/Library/Views/BookCardView.swift`
**描述**: 在书籍卡片上显示 OCR 状态
**验收标准**:
- [ ] 需要 OCR 的书显示标识（如扫描件图标）
- [ ] OCR 进行中显示进度条或动画
- [ ] OCR 完成后移除标识

### Task 3.2.6: 添加手动触发 OCR 入口
**文件**: `Modules/Library/Views/LibraryView.swift`
**描述**: 允许用户手动触发书籍 OCR
**验收标准**:
- [ ] 长按/右键书籍卡片显示上下文菜单
- [ ] 菜单包含"处理扫描件"选项（仅 `needsOCR=true` 时显示）
- [ ] 点击后将书籍加入 OCR 队列
- [ ] 显示开始处理的提示

### Task 3.2.7: OCR 错误处理
**文件**: `Core/PDF/OCRService.swift`
**描述**: 处理 OCR 过程中的错误
**验收标准**:
- [ ] 单页 OCR 失败不影响其他页
- [ ] 记录失败页码，支持重试
- [ ] 整体失败时通知用户
- [ ] 使用 `Logger.shared` 记录错误日志

---

## 技术实现要点

### 全局搜索数据流

```
用户输入搜索词
    ↓
LibraryView (debounce 300ms)
    ↓
DatabaseService.searchText(query:)
    ↓
FTS5 MATCH + bm25 排序
    ↓
GlobalSearchResultsView 显示结果
    ↓
点击结果 → AppState.selectedBook + initialPage
    ↓
ReaderView 打开并跳转
```

### OCR 处理流程

```
导入 PDF
    ↓
PDFService.isScannedPDF() 检测
    ↓ (是扫描件)
Book.needsOCR = true
    ↓
用户触发 OCR / 自动触发
    ↓
OCRService.processBook(bookId:)
    ↓
逐页: PDFService.performOCR() → DatabaseService.storeTextContent()
    ↓
Book.needsOCR = false
```

### 新增文件

| 文件路径 | 描述 |
|---------|------|
| `Modules/Search/Views/GlobalSearchResultsView.swift` | 全局搜索结果列表 |
| `Modules/Search/Views/GlobalSearchResultRow.swift` | 搜索结果行组件 |
| `Models/SearchResult.swift` | 搜索结果数据模型 |
| `Core/PDF/OCRService.swift` | OCR 任务管理服务 |

### 修改的文件

| 文件路径 | 修改内容 |
|---------|---------|
| `Models/Book.swift` | 添加 `needsOCR` 字段 |
| `Modules/Library/Views/LibraryView.swift` | 添加搜索栏和搜索结果视图 |
| `Modules/Library/Views/BookCardView.swift` | 显示 OCR 状态 |
| `Core/Storage/DatabaseService.swift` | 添加 `searchTextWithBookInfo()` 方法、OCR 标记迁移 |
| `Core/Storage/BookService.swift` | 导入时检测扫描件 |
| `Core/PDF/PDFService.swift` | 添加 `isScannedPDF()` 方法 |

---

## 建议实现顺序

1. **先完成 3.1 全局搜索 UI**（核心用户价值）
   - Task 3.1.4 → 3.1.1 → 3.1.2 → 3.1.3 → 3.1.5 → 3.1.6

2. **再完成 3.2 OCR 增强**（增强型功能）
   - Task 3.2.1 → 3.2.2 → 3.2.3 → 3.2.4 → 3.2.5 → 3.2.6 → 3.2.7

---

## 完成标志

Phase 3 完成的标志是:
1. [ ] 书架页有搜索栏，可输入关键词
2. [ ] 搜索结果显示书名、页码、匹配片段
3. [ ] 点击搜索结果可跳转到对应书籍和页面
4. [ ] 导入 PDF 时自动检测是否为扫描件
5. [ ] 扫描件可触发 OCR 处理
6. [ ] OCR 处理显示进度
7. [ ] OCR 完成后的书籍可被搜索到
