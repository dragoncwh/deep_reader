# DeepReader

一款以 PDF 为载体、以"理解一本书/一篇论文"为目标的学习型阅读软件。

## 🚀 快速开始

### 环境要求

- **Xcode 15.0+** (从 Mac App Store 安装)
- **iOS 16.0+** 目标设备
- **macOS 14.0+** (Sonoma) 开发机

### 1. 创建 Xcode 项目

由于 Xcode 项目文件复杂，请手动创建：

1. 打开 **Xcode**
2. **File → New → Project**
3. 选择 **iOS → App**
4. 配置:
   - **Product Name**: `DeepReader`
   - **Team**: 你的开发者账号 (可选)
   - **Organization Identifier**: `com.yourname`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: 不勾选
5. 保存到 `/Users/wenhuichen/workspace/ios/deep_reader/DeepReader/` 目录

### 2. 导入已有源码

项目创建后，将已有的源文件拖入 Xcode：

```
DeepReader/
├── App/
│   ├── DeepReaderApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Book.swift
│   └── Highlight.swift
├── Modules/
│   ├── Library/Views/LibraryView.swift
│   └── Reader/Views/ReaderView.swift
├── Core/
│   ├── PDF/PDFService.swift
│   └── Storage/
│       ├── DatabaseService.swift
│       └── BookService.swift
└── Shared/DesignSystem/DesignSystem.swift
```

### 3. 添加 GRDB 依赖

1. 在 Xcode 中：**File → Add Package Dependencies**
2. 输入 URL：`https://github.com/groue/GRDB.swift`
3. 选择版本：`7.0.0-beta.5` 或更高
4. 将 `GRDB` 添加到 `DeepReader` target

### 4. 配置 Info.plist

在 Xcode 中添加以下配置：

| Key | Type | Value |
|-----|------|-------|
| `Supports opening documents in place` | Boolean | YES |
| `Application supports iTunes file sharing` | Boolean | YES |

或手动添加到 Info.plist:
```xml
<key>UISupportsDocumentBrowser</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UIFileSharingEnabled</key>
<true/>
```

### 5. 运行项目

1. 选择模拟器或真机
2. **⌘ + R** 运行

---

## 📁 项目结构

```
DeepReader/
├── App/                    # 应用入口
├── Models/                 # 数据模型
├── Modules/                # 功能模块
│   ├── Library/            # 书库
│   └── Reader/             # 阅读器
├── Core/                   # 核心服务
│   ├── PDF/                # PDF 处理
│   └── Storage/            # 数据存储
└── Shared/                 # 共享资源
    └── DesignSystem/       # 设计系统
```

## 🛠 技术栈

| 领域 | 技术 |
|------|------|
| UI | SwiftUI + UIKit |
| PDF | PDFKit |
| OCR | Vision Framework |
| 数据库 | SQLite + GRDB.swift |
| 最低版本 | iOS 16+ |

## 📋 开发路线图

- [x] 项目架构搭建
- [ ] PDF 阅读功能
- [ ] 书库管理
- [ ] 搜索功能
- [ ] 高亮和笔记
- [ ] AI 问答 (Phase 2)

## 📚 学习资源

- [SwiftUI 官方教程](https://developer.apple.com/tutorials/swiftui)
- [PDFKit 文档](https://developer.apple.com/documentation/pdfkit)
- [GRDB.swift 文档](https://github.com/groue/GRDB.swift)
- [100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui)
