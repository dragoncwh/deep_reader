# DeepReader 开发路线图 (Roadmap)

## 当前状态总结

### 已完成 ✅
- **数据层**: GRDB + SQLite + FTS5 全文搜索
- **Models**: Book, Highlight, SearchResult (含GRDB协议)
- **Services**: DatabaseService, PDFService, BookService, OCRService
- **基础UI**: LibraryView (网格布局), ReaderView (PDFKit包装)
- **Design System**: Typography, Spacing, Colors, Components
- **Phase 1**: 完整的 导入→书架→阅读→进度保存 流程
- **Phase 2**: 高亮与笔记功能 (创建、显示、管理)
- **Phase 3**: 全局搜索 + OCR 扫描件支持

---

## Phase 1: 完成基础流程 (MVP) ✅
**目标**: 让 导入→书架→阅读→进度保存 完整跑通

> 详细任务拆解见 [PHASE1_TASKS.md](./PHASE1_TASKS.md)

### 1.1 接通导入流程 ✅
- [x] `ContentView.importPDF()` 调用 `BookService.importPDF()`
- [x] 导入成功后刷新 LibraryView
- [x] 添加导入进度指示和错误提示

### 1.2 接通书架显示 ✅
- [x] `LibraryViewModel.loadBooks()` 调用 `DatabaseService.fetchBooks()`
- [x] 实现 `deleteBook()` 功能 (滑动删除)
- [x] 封面图片正确加载

### 1.3 接通阅读进度 ✅
- [x] `ReaderViewModel.saveProgress()` 调用 `DatabaseService.updateReadingProgress()`
- [x] 打开书籍时恢复上次阅读位置

---

## Phase 2: 高亮与笔记 ✅
**目标**: 用户可以高亮文本并添加笔记

> 详细任务拆解见 [PHASE2_TASKS.md](./PHASE2_TASKS.md)

### 2.1 高亮创建 ✅
- [x] 长按/选中文本后显示高亮菜单
- [x] 支持5种高亮颜色选择
- [x] 保存高亮到数据库

### 2.2 高亮显示 ✅
- [x] 在PDF页面上渲染已有高亮 (PDFAnnotation)
- [x] 点击高亮显示详情/笔记

### 2.3 高亮管理 ✅
- [x] 高亮列表视图 (按页码分组)
- [x] 删除高亮
- [x] 编辑笔记

---

## Phase 3: 全局搜索 ✅
**目标**: 跨书籍搜索，支持扫描件OCR

> 详细任务拆解见 [PHASE3_TASKS.md](./PHASE3_TASKS.md)

### 3.1 全局搜索UI ✅
- [x] 书架页添加搜索栏
- [x] 搜索结果列表 (显示书名、页码、匹配片段)
- [x] 点击结果跳转到对应位置
- [x] 搜索防抖 (300ms)

### 3.2 OCR增强 ✅
- [x] 检测PDF是否为扫描件 (无文本层)
- [x] 导入时自动标记扫描件
- [x] OCR处理队列 (OCRService)
- [x] OCR进度显示
- [x] 书架显示OCR状态徽章
- [x] 手动触发OCR (长按菜单)
- [x] OCR错误处理与重试

---

## Phase 4: AI辅助理解 (核心差异化)
**目标**: 受约束的AI，只基于当前书籍回答，答案可回溯原文

### 4.1 基础AI集成
- [ ] AI服务抽象层 (支持Claude/OpenAI)
- [ ] API Key管理 (本地加密存储)
- [ ] 用户同意界面 (首次使用AI时)

### 4.2 阅读器内AI对话
- [ ] 底部AI对话面板
- [ ] 选中文本后"解释这段"
- [ ] 上下文限定在当前书籍

### 4.3 引用回溯 (关键特性)
- [ ] AI回答中标注来源页码
- [ ] 点击引用跳转并高亮原文
- [ ] "这段在原文哪里?" 功能

---

## Phase 5: 隐私与离线
**目标**: 默认离线，云端AI需明确同意

### 5.1 隐私控制
- [ ] 设置页：AI开关、API配置
- [ ] 首次AI使用确认对话框
- [ ] 显示将发送什么内容

### 5.2 离线功能
- [ ] 本地全文搜索 (已有FTS5)
- [ ] 离线高亮/笔记
- [ ] 可选的本地小模型 (未来)

---

## Phase 6: 打磨与优化

### 6.1 大PDF性能
- [ ] 懒加载页面
- [ ] 文本提取后台队列
- [ ] 内存优化

### 6.2 大型书籍库优化 (几百本书场景)
- [ ] 书架分页加载 (一次加载50本，滚动加载更多)
- [ ] 文本存储优化 (压缩或按需提取)
- [ ] FTS5索引优化 (external content模式)
- [ ] 数据库定期VACUUM压缩

> **问题背景**: 当前实现每本书会在数据库存储完整文本用于搜索。
> 假设200本书，平均200页/本，每页2KB文本：
> - 文本数据: ~80 MB
> - FTS5索引: ~160-240 MB
> - 总额外存储: ~200-300 MB (不含PDF本身)
>
> 当前设计对几百本书可接受，但1000+本书需要优化。

### 6.3 用户体验
- [ ] 深色模式支持
- [ ] 阅读设置 (字体、亮度)
- [ ] iPad适配

---

## 建议优先级

| 阶段 | 优先级 | 状态 | 原因 |
|------|--------|------|------|
| Phase 1 | 🔴 必须 | ✅ 完成 | 基础流程不通，无法使用 |
| Phase 2 | 🟠 高 | ✅ 完成 | 学习型阅读器的基本功能 |
| Phase 3 | 🟡 中 | ✅ 完成 | 提升可用性 |
| Phase 4 | 🔴 必须 | 待开发 | 产品核心差异化 |
| Phase 5 | 🟠 高 | 待开发 | 用户信任的基础 |
| Phase 6 | 🟡 中 | 待开发 | 上线前打磨 |

---

## 关键文件

**已完成模块:**
- `ContentView.swift` - PDF导入 ✅
- `LibraryView.swift` - 书架显示、全局搜索 ✅
- `ReaderView.swift` - 阅读器、高亮功能 ✅
- `HighlightDetailView.swift` - 高亮详情 ✅
- `HighlightListView.swift` - 高亮列表 ✅
- `NoteEditorView.swift` - 笔记编辑器 ✅
- `Modules/Search/Views/GlobalSearchResultsView.swift` - 全局搜索结果 ✅
- `Modules/Search/Views/GlobalSearchResultRow.swift` - 搜索结果行 ✅
- `Models/SearchResult.swift` - 搜索结果模型 ✅
- `Core/PDF/OCRService.swift` - OCR处理服务 ✅

**需新增:**
- `Modules/AI/` - AI服务和对话UI
- `Modules/Settings/` - 设置页面
