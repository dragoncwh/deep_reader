# Phase 1: 完成基础流程 (MVP) - 任务拆解

## 目标
让 **导入 → 书架 → 阅读 → 进度保存** 完整跑通

---

## 1.1 接通导入流程 ✅

### Task 1.1.1: 实现 PDF 导入调用 ✅
**文件**: `ContentView.swift`
**描述**: 在 `importPDF()` 方法中调用 `BookService.importPDF()`
**验收标准**:
- [x] 选择 PDF 文件后，调用 `BookService.shared.importPDF(from: url)`
- [x] 使用 async/await 处理异步导入

### Task 1.1.2: 导入成功后刷新书架 ✅
**文件**: `ContentView.swift`, `LibraryView.swift`
**描述**: 导入完成后通知 LibraryView 刷新数据
**验收标准**:
- [x] 导入成功后触发 `LibraryViewModel.loadBooks()` 重新加载
- [x] 使用 Notification 机制 (`.bookImported`)

### Task 1.1.3: 添加导入进度指示 ✅
**文件**: `ContentView.swift`
**描述**: 在导入过程中显示加载状态
**验收标准**:
- [x] 添加 `isImporting` 状态变量
- [x] 导入时显示 ProgressView 加载动画
- [x] 导入完成后隐藏加载状态

### Task 1.1.4: 添加导入错误提示 ✅
**文件**: `ContentView.swift`
**描述**: 导入失败时显示用户友好的错误信息
**验收标准**:
- [x] 使用 `.alert()` 显示错误信息
- [x] 错误信息用户友好 (使用 LocalizedError)
- [x] 处理 `BookServiceError` 的各种情况

---

## 1.2 接通书架显示 ✅

### Task 1.2.1: 实现 loadBooks() 数据库调用 ✅
**文件**: `LibraryView.swift`
**描述**: 在 `LibraryViewModel.loadBooks()` 中调用 DatabaseService
**验收标准**:
- [x] 调用 `BookService.shared.fetchAllBooks()` 加载书籍
- [x] 将结果赋值给 `books` 数组
- [x] 添加错误处理

### Task 1.2.2: 页面加载时自动获取书籍 ✅
**文件**: `LibraryView.swift`
**描述**: 在视图出现时加载书籍列表
**验收标准**:
- [x] 使用 `.task` 调用 `loadBooks()`
- [x] 添加 `isLoading` 状态显示加载中

### Task 1.2.3: 实现删除功能 ✅
**文件**: `LibraryView.swift`
**描述**: 实现 `deleteBook()` 方法删除书籍
**验收标准**:
- [x] 调用 `BookService.shared.deleteBook()` 删除
- [x] 同时删除相关的文本内容和高亮 (级联删除)
- [x] 删除后刷新书籍列表
- [x] 添加删除确认对话框

### Task 1.2.4: 封面图片正确加载 ✅
**文件**: `LibraryView.swift`, `BookCardView`
**描述**: 确保 BookCardView 正确显示封面图片
**验收标准**:
- [x] 从 `Book.coverImagePath` 加载封面图片
- [x] 处理封面不存在的情况 (显示占位图)
- [x] 优化图片加载性能 (异步加载)

---

## 1.3 接通阅读进度 ✅

### Task 1.3.1: 实现保存阅读进度 ✅
**文件**: `ReaderView.swift`
**描述**: 在 `ReaderViewModel.saveProgress()` 中保存当前页码
**验收标准**:
- [x] 调用 `BookService.shared.updateProgress()` 保存进度
- [x] 在页面切换时触发保存 (使用 Combine 防抖 1 秒)

### Task 1.3.2: 监听页面变化 ✅
**文件**: `ReaderView.swift`, `PDFKitView`
**描述**: 监听 PDFView 的页面变化通知
**验收标准**:
- [x] 监听 `PDFViewPageChanged` 通知
- [x] 页面变化时更新 ViewModel 中的 currentPage
- [x] 触发 `saveProgress()`

### Task 1.3.3: 打开书籍时恢复阅读位置 ✅
**文件**: `ReaderView.swift`
**描述**: 打开书籍时跳转到上次阅读的页面
**验收标准**:
- [x] 从 `Book.lastReadPage` 获取上次页码
- [x] 使用 `PDFDocument.page(at:)` 获取对应页面
- [x] 使用 `pdfView.go(to:)` 跳转到该页面

### Task 1.3.4: 更新阅读进度百分比 ✅
**文件**: `ReaderView.swift`, `Book.swift`
**描述**: 同时更新进度百分比用于书架显示
**验收标准**:
- [x] 计算 `progress = lastReadPage / pageCount` (Book.readingProgress)
- [x] 保存 `lastReadPage` 到 Book 表
- [x] 书架卡片显示进度条

---

## 额外修复

### 数据库初始化
**文件**: `DeepReaderApp.swift`
**描述**: 在应用启动时初始化数据库
- [x] 在 `AppState.setupServices()` 中调用 `DatabaseService.shared.setup()`

---

## 依赖关系

```
1.2.1 (loadBooks) ──┐
                    ├──→ 1.1.2 (刷新书架)
1.1.1 (导入调用) ───┘

1.3.2 (监听页面) ──→ 1.3.1 (保存进度)

1.3.3 (恢复位置) 独立

1.3.4 (进度百分比) 依赖 1.3.1
```

---

## 完成标志 ✅

Phase 1 完成的标志是:
1. ✅ 用户可以从文件选择器导入 PDF
2. ✅ 导入的 PDF 在书架上正确显示 (封面 + 标题)
3. ✅ 点击书籍可以打开阅读
4. ✅ 关闭并重新打开书籍时，恢复到上次阅读的位置
5. ✅ 可以删除书籍
