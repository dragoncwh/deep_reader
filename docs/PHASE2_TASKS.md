# Phase 2: 高亮与笔记 - 任务拆解

## 目标
让用户可以 **高亮文本 → 选择颜色 → 添加笔记 → 管理高亮**

---

## 现有基础

### 已完成的基础设施
- **Highlight 模型** (`Models/Highlight.swift`)
  - 支持 5 种颜色 (yellow, green, blue, pink, purple)
  - 包含 bookId, pageNumber, text, note, color, boundsData
  - 已实现 GRDB 协议
- **DatabaseService** (`Core/Storage/DatabaseService.swift`)
  - `fetchHighlights(bookId:)` - 获取书籍高亮
  - `saveHighlight(_:)` - 保存高亮
  - `deleteHighlight(_:)` - 删除高亮
- **PDFKitView** - 已启用文本选择

### 需要实现
- 高亮创建 UI（选中文本后的菜单）
- 高亮渲染（在 PDF 页面上绘制）
- 高亮管理界面

---

## 2.1 高亮创建

### Task 2.1.1: 检测文本选中状态
**文件**: `ReaderView.swift`, `PDFKitView`
**描述**: 监听 PDFView 的文本选中事件，获取选中文本和位置
**验收标准**:
- [ ] 监听 `PDFViewSelectionChanged` 通知
- [ ] 获取选中的 `PDFSelection` 对象
- [ ] 提取选中文本内容 (`selection.string`)
- [ ] 获取选中区域的边界框 (`selection.bounds(for:)`)

### Task 2.1.2: 创建高亮颜色选择菜单
**文件**: `Modules/Reader/Views/HighlightMenuView.swift` (新建)
**描述**: 选中文本后显示浮动菜单，包含颜色选择
**验收标准**:
- [ ] 创建 `HighlightMenuView` 组件
- [ ] 显示 5 种高亮颜色按钮 (使用 `HighlightColor.allCases`)
- [ ] 菜单定位在选中文本附近
- [ ] 点击颜色后触发高亮创建回调
- [ ] 点击菜单外部关闭菜单

### Task 2.1.3: 实现高亮保存逻辑
**文件**: `ReaderView.swift` (ReaderViewModel)
**描述**: 将选中文本和颜色保存为高亮记录
**验收标准**:
- [ ] 在 `ReaderViewModel` 添加 `createHighlight(selection:color:)` 方法
- [ ] 将 `PDFSelection.bounds` 转换为 `boundsData` (JSON 编码 CGRect 数组)
- [ ] 调用 `DatabaseService.saveHighlight()` 保存
- [ ] 保存成功后刷新页面高亮显示

### Task 2.1.4: 添加高亮创建动画反馈
**文件**: `ReaderView.swift`
**描述**: 高亮创建成功后提供视觉反馈
**验收标准**:
- [ ] 创建成功时显示短暂的成功动画
- [ ] 使用 haptic feedback 震动反馈
- [ ] 菜单自动关闭

---

## 2.2 高亮显示

### Task 2.2.1: 加载书籍高亮数据
**文件**: `ReaderView.swift` (ReaderViewModel)
**描述**: 打开书籍时加载该书的所有高亮
**验收标准**:
- [ ] 在 `ReaderViewModel` 添加 `@Published var highlights: [Highlight]`
- [ ] 在 `loadDocument()` 中调用 `DatabaseService.fetchHighlights()`
- [ ] 高亮数据按页码组织，便于渲染

### Task 2.2.2: 自定义 PDFPage 绘制高亮
**文件**: `Modules/Reader/Views/HighlightedPDFView.swift` (新建)
**描述**: 通过自定义 PDFPage 子类在页面上渲染高亮
**验收标准**:
- [ ] 创建 `HighlightOverlayView` 或使用 PDFKit annotation
- [ ] 根据 `boundsData` 计算高亮绘制位置
- [ ] 使用对应 `HighlightColor.color` 绘制半透明矩形
- [ ] 支持多个不连续选区的高亮

### Task 2.2.3: 高亮点击交互
**文件**: `ReaderView.swift`, `PDFKitView`
**描述**: 点击已有高亮时显示详情
**验收标准**:
- [ ] 检测点击位置是否在高亮区域内
- [ ] 点击高亮时显示 `HighlightDetailView`
- [ ] 显示高亮文本、颜色、笔记内容
- [ ] 提供删除和编辑笔记入口

### Task 2.2.4: 创建高亮详情弹窗
**文件**: `Modules/Reader/Views/HighlightDetailView.swift` (新建)
**描述**: 显示高亮详情和操作选项的弹窗
**验收标准**:
- [ ] 显示高亮的文本内容（带颜色标识）
- [ ] 显示笔记内容（如果有）
- [ ] 提供"编辑笔记"按钮
- [ ] 提供"删除高亮"按钮（带确认）
- [ ] 提供"更改颜色"选项

---

## 2.3 高亮管理

### Task 2.3.1: 创建高亮列表视图
**文件**: `Modules/Reader/Views/HighlightListView.swift` (新建)
**描述**: 显示当前书籍的所有高亮列表
**验收标准**:
- [ ] 创建 `HighlightListView` 视图
- [ ] 按页码分组显示高亮
- [ ] 每条高亮显示：颜色标记、文本摘要、页码、笔记预览
- [ ] 从 ReaderView 工具栏可以打开此视图

### Task 2.3.2: 高亮列表导航功能
**文件**: `HighlightListView.swift`
**描述**: 点击高亮列表项跳转到对应页面
**验收标准**:
- [ ] 点击高亮项触发页面跳转
- [ ] 使用 `ReaderViewModel.goToPage()` 方法
- [ ] 跳转后关闭高亮列表
- [ ] 高亮跳转后短暂闪烁对应高亮区域

### Task 2.3.3: 实现删除高亮功能
**文件**: `HighlightListView.swift`, `ReaderViewModel`
**描述**: 支持从列表中删除高亮
**验收标准**:
- [ ] 支持滑动删除手势
- [ ] 删除前显示确认对话框
- [ ] 调用 `DatabaseService.deleteHighlight()` 删除
- [ ] 删除后更新 UI（列表和页面渲染）

### Task 2.3.4: 实现编辑笔记功能
**文件**: `Modules/Reader/Views/NoteEditorView.swift` (新建)
**描述**: 提供笔记编辑界面
**验收标准**:
- [ ] 创建 `NoteEditorView` 编辑界面
- [ ] 使用 `TextEditor` 支持多行文本输入
- [ ] 保存时调用 `DatabaseService.saveHighlight()` 更新
- [ ] 支持键盘自适应布局
- [ ] 保存成功后返回并刷新显示

### Task 2.3.5: 在工具栏添加高亮列表入口
**文件**: `ReaderView.swift`
**描述**: 在阅读器工具栏添加高亮列表按钮
**验收标准**:
- [ ] 在工具栏添加高亮图标按钮 (如 `highlighter` 或 `bookmark`)
- [ ] 点击按钮打开 `HighlightListView` sheet
- [ ] 如果没有高亮，显示空状态提示

---

## 依赖关系

```
2.1.1 (检测选中) ──→ 2.1.2 (颜色菜单) ──→ 2.1.3 (保存高亮)
                                              │
                                              ↓
2.2.1 (加载高亮) ←─────────────────────────────┘
      │
      ↓
2.2.2 (渲染高亮) ──→ 2.2.3 (点击交互) ──→ 2.2.4 (详情弹窗)
      │
      ↓
2.3.1 (高亮列表) ──→ 2.3.2 (导航跳转)
      │
      ├──→ 2.3.3 (删除高亮)
      │
      └──→ 2.3.4 (编辑笔记)

2.3.5 (工具栏入口) 独立，可并行开发
```

---

## 技术要点

### PDFKit 高亮渲染方案选择

**方案 A: 使用 PDFAnnotation (推荐)**
```swift
let annotation = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
annotation.color = UIColor.yellow.withAlphaComponent(0.4)
page.addAnnotation(annotation)
```
- 优点：原生支持，性能好，自动跟随缩放
- 缺点：修改原 PDF（内存中）

**方案 B: 自定义 Overlay View**
- 在 PDFView 上叠加透明视图绘制高亮
- 优点：不修改 PDF
- 缺点：需要处理缩放和滚动同步

### 坐标转换

PDFKit 使用 PDF 坐标系（左下角为原点），需要与 UIKit 坐标系转换：
```swift
// PDF 坐标 -> View 坐标
let viewRect = pdfView.convert(pdfRect, from: page)

// View 坐标 -> PDF 坐标
let pdfRect = pdfView.convert(viewRect, to: page)
```

### boundsData 存储格式

高亮可能跨多行，存储多个 CGRect：
```swift
let rects: [CGRect] = selection.selectionsByLine().map {
    $0.bounds(for: page)
}
let data = try JSONEncoder().encode(rects)
```

---

## 需要新建的文件

| 文件路径 | 描述 |
|---------|------|
| `Modules/Reader/Views/HighlightMenuView.swift` | 高亮颜色选择菜单 |
| `Modules/Reader/Views/HighlightDetailView.swift` | 高亮详情弹窗 |
| `Modules/Reader/Views/HighlightListView.swift` | 高亮列表视图 |
| `Modules/Reader/Views/NoteEditorView.swift` | 笔记编辑器 |

---

## 需要修改的文件

| 文件路径 | 修改内容 |
|---------|---------|
| `ReaderView.swift` | 添加高亮相关状态和方法 |
| `PDFKitView` | 添加选中监听和高亮渲染 |
| `ReaderViewModel` | 添加高亮 CRUD 方法 |

---

## 完成标志

Phase 2 完成的标志是:
1. [ ] 用户可以选中文本并创建高亮
2. [ ] 高亮可以选择 5 种颜色之一
3. [ ] 已创建的高亮在 PDF 页面上正确显示
4. [ ] 点击高亮可以查看详情和笔记
5. [ ] 可以为高亮添加/编辑笔记
6. [ ] 可以从高亮列表跳转到对应页面
7. [ ] 可以删除高亮
8. [ ] 关闭并重新打开书籍后，高亮正确恢复显示
