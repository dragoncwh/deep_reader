# Phase 1: 完成基础流程 (MVP) - 任务拆解

## 目标
让 **导入 → 书架 → 阅读 → 进度保存** 完整跑通

---

## 1.1 接通导入流程

### Task 1.1.1: 实现 PDF 导入调用
**文件**: `ContentView.swift`
**描述**: 在 `importPDF()` 方法中调用 `BookService.importPDF()`
**验收标准**:
- [ ] 选择 PDF 文件后，调用 `BookService.shared.importPDF(from: url)`
- [ ] 使用 async/await 处理异步导入

### Task 1.1.2: 导入成功后刷新书架
**文件**: `ContentView.swift`, `LibraryView.swift`
**描述**: 导入完成后通知 LibraryView 刷新数据
**验收标准**:
- [ ] 导入成功后触发 `LibraryViewModel.loadBooks()` 重新加载
- [ ] 考虑使用 `@Environment` 或 Notification 机制

### Task 1.1.3: 添加导入进度指示
**文件**: `ContentView.swift`
**描述**: 在导入过程中显示加载状态
**验收标准**:
- [ ] 添加 `isImporting` 状态变量
- [ ] 导入时显示 ProgressView 或加载动画
- [ ] 导入完成后隐藏加载状态

### Task 1.1.4: 添加导入错误提示
**文件**: `ContentView.swift`
**描述**: 导入失败时显示用户友好的错误信息
**验收标准**:
- [ ] 使用 `.alert()` 显示错误信息
- [ ] 错误信息需本地化/用户友好
- [ ] 处理 `BookServiceError` 的各种情况

---

## 1.2 接通书架显示

### Task 1.2.1: 实现 loadBooks() 数据库调用
**文件**: `LibraryView.swift`
**描述**: 在 `LibraryViewModel.loadBooks()` 中调用 DatabaseService
**验收标准**:
- [ ] 调用 `DatabaseService.shared.fetchAllBooks()` 或类似方法
- [ ] 将结果赋值给 `books` 数组
- [ ] 添加错误处理

### Task 1.2.2: 页面加载时自动获取书籍
**文件**: `LibraryView.swift`
**描述**: 在视图出现时加载书籍列表
**验收标准**:
- [ ] 使用 `.onAppear` 或 `.task` 调用 `loadBooks()`
- [ ] 添加 `isLoading` 状态显示加载中

### Task 1.2.3: 实现滑动删除功能
**文件**: `LibraryView.swift`
**描述**: 实现 `deleteBook()` 方法删除书籍
**验收标准**:
- [ ] 调用 `BookService.shared.deleteBook()` 或 `DatabaseService` 删除
- [ ] 同时删除相关的文本内容和高亮
- [ ] 删除后刷新书籍列表
- [ ] 添加删除确认对话框 (可选)

### Task 1.2.4: 封面图片正确加载
**文件**: `LibraryView.swift`, `BookCardView` 相关代码
**描述**: 确保 BookCardView 正确显示封面图片
**验收标准**:
- [ ] 从 `Book.coverPath` 加载封面图片
- [ ] 处理封面不存在的情况 (显示占位图)
- [ ] 优化图片加载性能 (异步加载)

---

## 1.3 接通阅读进度

### Task 1.3.1: 实现保存阅读进度
**文件**: `ReaderView.swift`
**描述**: 在 `ReaderViewModel.saveProgress()` 中保存当前页码
**验收标准**:
- [ ] 调用 `DatabaseService.shared.updateReadingProgress(bookId:, currentPage:)`
- [ ] 在页面切换时触发保存 (可做防抖处理)

### Task 1.3.2: 监听页面变化
**文件**: `ReaderView.swift`, `PDFKitView`
**描述**: 监听 PDFView 的页面变化通知
**验收标准**:
- [ ] 监听 `PDFViewPageChanged` 通知
- [ ] 页面变化时更新 ViewModel 中的 currentPage
- [ ] 触发 `saveProgress()`

### Task 1.3.3: 打开书籍时恢复阅读位置
**文件**: `ReaderView.swift`
**描述**: 打开书籍时跳转到上次阅读的页面
**验收标准**:
- [ ] 从 `Book.currentPage` 获取上次页码
- [ ] 使用 `PDFDocument.page(at:)` 获取对应页面
- [ ] 使用 `pdfView.go(to:)` 跳转到该页面

### Task 1.3.4: 更新阅读进度百分比
**文件**: `ReaderView.swift`, `DatabaseService.swift`
**描述**: 同时更新进度百分比用于书架显示
**验收标准**:
- [ ] 计算 `progress = currentPage / totalPages`
- [ ] 保存 `progress` 到 Book 表
- [ ] 书架卡片显示进度条

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

## 建议执行顺序

1. **Task 1.2.1** - 先让书架能显示数据库中的书籍
2. **Task 1.2.2** - 页面加载时获取书籍
3. **Task 1.2.4** - 封面正确显示
4. **Task 1.1.1** - 实现导入调用
5. **Task 1.1.2** - 导入后刷新书架
6. **Task 1.1.3** - 导入进度指示
7. **Task 1.1.4** - 导入错误提示
8. **Task 1.2.3** - 滑动删除
9. **Task 1.3.2** - 监听页面变化
10. **Task 1.3.1** - 保存阅读进度
11. **Task 1.3.3** - 恢复阅读位置
12. **Task 1.3.4** - 更新进度百分比

---

## 预估工作量

| 模块 | 任务数 | 复杂度 |
|------|--------|--------|
| 1.1 导入流程 | 4 | 中等 |
| 1.2 书架显示 | 4 | 简单 |
| 1.3 阅读进度 | 4 | 中等 |
| **总计** | **12** | - |

---

## 完成标志

Phase 1 完成的标志是:
1. 用户可以从文件选择器导入 PDF
2. 导入的 PDF 在书架上正确显示 (封面 + 标题)
3. 点击书籍可以打开阅读
4. 关闭并重新打开书籍时，恢复到上次阅读的位置
5. 可以删除书籍
