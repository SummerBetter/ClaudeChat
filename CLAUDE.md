# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目目标

一个 macOS App，模拟命令行 `claude -p` 发起对话。支持多会话管理、Markdown 渲染、用户个性化设置。

## 技术栈

- Swift 5.9 / SwiftUI / Swift Package Manager
- 最低系统 macOS 14
- 调用本地 `claude` CLI（通过 nvm 安装），解析 `stream-json` 输出
- 会话持久化到 `~/Library/Application Support/ClaudeChat/sessions.json`
- 用户设置通过 `UserDefaults` 持久化

## 构建与运行

```bash
./run.sh
```

## 架构

```
App (NavigationSplitView)
├── SessionListView              侧边栏：会话列表、新建/选中/重命名/删除、设置齿轮按钮
├── ChatView                     聊天主界面（SessionStore 注入 ChatViewModel + UserProfileStore）
│   ├── MarkdownBlockView        代码块/表格/段落渲染
│   │   └── MarkdownParser       文本 → [MarkdownBlock] 解析
│   └── ChatViewModel (ObservedObject)
│       └── ClaudeExecutor (actor)
├── NewSessionView (Sheet)       新建会话：名称 + 工作目录 + 权限说明
├── SettingsView (Sheet)         用户头像(Emoji)/昵称/颜色配置
└── UserProfileStore             用户资料管理 + UserDefaults 持久化
```

### 关键数据流

```
用户输入 → ChatViewModel.send(text, images)
  → ClaudeExecutor.send(text, images)
    → Process stdin: JSONL {"type":"user","message":{"role":"user","content":[...]}}
    → Process stdout: stream-json
    → 后台 Task 持续读取 stdout → onEvent(MessageContent) 回调
    → @MainActor 追加到 ChatMessage.contents
    → onTurnComplete 回调 → isRunning = false
    → onSessionId 回调 → SessionStore 持久化 session_id
  → onMessagesChanged 回调 → SessionStore 持久化消息列表
```

ClaudeExecutor 使用 stdin JSONL 协议（非 `-p` 模式），每个会话持有长期 Process：
- `launch()`：启动 `claude --output-format stream-json --permission-mode <mode> --verbose [--resume <sid>] [--add-dir <wd>]`
- `send()`：向 stdin 写入用户消息 JSONL，支持 text + base64 图片 content blocks
- `terminate()`：关闭 stdin + terminate 进程

### 权限模式

每个会话可独立选择：
- **仅工作目录** (`acceptEdits`)：Write/Bash/Read 只在 `--add-dir` 范围内放行
- **全部放行** (`bypassPermissions`)：所有工具自动执行

### 文件职责

- **Session.swift**: `PermMode` 枚举、`MessageContent` 枚举(text/image/toolUse/toolResult/thinking)、`ChatMessage`、`Session`
- **SessionStore.swift**: 会话 CRUD + ViewModel 缓存 + sessions.json 持久化
- **ClaudeExecutor.swift**: 封装 `Process`，用 `JSONSerialization` 解析 JSONL，传递 `MessageContent` 回调
- **ChatViewModel.swift**: 由 SessionStore 注入构造，管理消息列表 + 权限模式
- **ChatView.swift**: 聊天气泡 + MarkdownBlockView 渲染 + 权限切换 + 用户头像/昵称
- **MarkdownParser.swift**: 文本按行扫描，输出 `[MarkdownBlock]`（paragraph/codeBlock/table/divider）
- **MarkdownBlockView.swift**: 代码块(等宽字体+复制按钮)、表格(Grid 布局)、段落(AttributedString markdown)
- **UserProfile.swift**: `UserProfileStore`(ObservableObject) + `UserProfile` 模型 + `Color(hex:)` 扩展
- **SettingsView.swift**: Emoji 选择器 + 颜色选择器 + 昵称输入
- **SessionListView.swift**: 侧边栏 + 工具栏设置按钮
- **NewSessionView.swift**: 新建会话 Sheet
- **App.swift**: NavigationSplitView + UserProfileStore + 全局 tint