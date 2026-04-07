# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | **中文** | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

一款 macOS 原生通知应用，专为 Claude Code 设计。在任务完成或需要输入时接收通知。

点击通知即可导航到 Claude Code 正在运行的**精确窗口和标签页**。

## 功能特性

- **菜单栏常驻应用** — 菜单栏显示铃铛图标，无 Dock 图标
- **Sparkle 自动更新** — 自动检查 GitHub Releases，一键安装
- **多语言支持** — 7 种语言（en、ko、zh、ja、es、vi、pt），自动检测系统语言，支持手动切换
- **通知历史** — 内存中保存最近 10 条通知，可在菜单栏查看
- **IPC 投递** — 应用已运行时，通过 `DistributedNotificationCenter` 传递新通知，无需启动新进程
- **登录时启动** — 默认开启，可在设置中切换
- 原生 macOS 通知（`UNUserNotificationCenter`）
- 通知中显示源应用图标和项目名称
- 点击即可导航到精确的窗口/标签页：

| 环境 | 通知 | 点击导航 | 全屏 Space | 方式 |
|------|:----:|:------:|:----------:|------|
| iTerm | O | 窗口 + 标签页 | O | Session GUID + SkyLight API |
| Cursor | O | 项目窗口 | O | Workspace path + SkyLight API |
| VS Code | O | 项目窗口 | O | Workspace path + SkyLight API |
| macOS Terminal | O | 窗口 + 标签页 | O | TTY path + SkyLight API |
| Warp | O | 应用激活 | X | open -b (Rust 应用限制) |

## 系统要求

- macOS 14+（Sonoma 或更高版本）
- Swift 5.9+
- Claude Code CLI

## 安装

### 方式一：预构建下载（DMG）

1. 从 [Releases](https://github.com/isaac9711/claude-notify/releases) 下载适用于您 macOS 版本的 DMG
2. 打开 DMG
3. 将 `ClaudeNotify.app` 拖入 `Applications` 文件夹
4. 首次启动时，如果出现安全警告，**右键点击 → 打开 → 打开**（仅需一次）

> **提示：** 您也可以在终端中运行 `xattr -cr /Applications/ClaudeNotify.app` 来跳过安全警告。

### 方式二：源码构建

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### 升级

应用支持通过 **Sparkle 自动更新** — 点击菜单栏中的"检查更新"即可更新。如需从源码构建，请运行 `git pull && ./build.sh`。

任何更新后，请在系统设置 > 辅助功能中将 ClaudeNotify **关闭 → 开启**（二进制文件哈希变更会使权限失效）。

> `~/.claude/settings.json` 中的 Hook 配置会保留，无需修改。

## 设置

### 1. macOS 权限

**启动应用（首次启动）：**

直接启动 ClaudeNotify.app 即可 — 在 Finder 中双击或通过 Spotlight 打开。应用将常驻于菜单栏，并默认在登录时自动启动。首次启动会自动弹出辅助功能和通知权限请求对话框。

**终端自动化（如果使用 Terminal.app）：**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
当提示"ClaudeNotify wants to control Terminal"时，点击允许。

### 2. Claude Code Hook 配置

将以下内容添加到 `~/.claude/settings.json` 的 `hooks` 部分：

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"等待输入 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"任务完成 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Git Worktree 工作区路径配置

默认 Hook 使用 `git rev-parse --git-common-dir` 始终解析到**基础项目根目录**。这可以防止 Claude Code 创建 worktree 时打开新窗口。

| 场景 | 默认值 (git common dir) | 替代方案 (git show-toplevel) |
|----------|:---:|:---:|
| 基础项目窗口 | 跳转到基础窗口 ✓ | 跳转到基础窗口 ✓ |
| Worktree 窗口（单独打开） | 跳转到基础窗口 | 跳转到 Worktree 窗口 ✓ |
| Claude Code 创建的 worktree（无窗口） | 跳转到基础窗口 ✓ | 创建新窗口 |

如果您主要使用单独的 Cursor/VS Code 窗口打开 worktree 进行开发，请替换 Hook 中的 workspace 部分：

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
```

## 工作原理

### 通知流程

```
Claude Code hook 触发
    |
    +-- 通过 $__CFBundleIdentifier 识别应用（iTerm、Cursor、VS Code、Terminal）
    +-- 捕获会话信息：
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> 通过 ps 获取 tty 路径
    |     其他    -> （无，使用工作区路径）
    |
    +-- ClaudeNotify 是否已在运行？
          |
          +-- 是 -> 通过 DistributedNotificationCenter 进行 IPC 投递
          |          应用接收负载 → 发送 UNUserNotification → 更新历史记录
          |
          +-- 否 -> 启动 ClaudeNotify.app（常驻于菜单栏）
                     |
                     +-- 通过 UNUserNotificationCenter 发送通知
                     +-- 附加源应用图标
                     +-- 将 session/workspace 信息存入通知历史
```

### 点击导航流程

```
点击通知
    |
    +-- 应用已在运行（菜单栏常驻）
    +-- didReceive 处理器直接被调用
    |
    +-- 判断会话类型：
          |
          +-- /dev/tty*  -> Terminal AppleScript（TTY 匹配）
          +-- w*t*p*:*   -> iTerm AppleScript（GUID 匹配）
          +-- activate-only -> Warp（仅激活应用）
          +-- (其他)     -> open -b <bundleId> <workspace>
```

### 各终端导航方式

**iTerm：**
- 从 `ITERM_SESSION_ID` 提取会话 GUID
- AppleScript 遍历所有窗口/标签页/会话以查找匹配的 GUID
- 选中匹配的窗口 + 标签页

**macOS Terminal：**
- 通过 `ps -o tty= -p $PPID` 获取父进程的 TTY 路径
- AppleScript 遍历所有窗口/标签页以匹配 TTY
- 将匹配的标签页设为选中状态，并将窗口置于前台

**Cursor / VS Code：**
- 将 `$PWD`（工作目录）作为工作区路径传入
- `open -b <bundleId> <workspace>` 激活对应的项目窗口
- 每个项目有独立的窗口，确保导航精准

## 菜单栏

ClaudeNotify 以铃铛图标（`􀋚`）常驻于菜单栏。点击图标可访问：

- **最近通知** — 最近 10 条通知，含标题、消息和时间戳；点击条目可导航到对应会话
- **检查更新** — 手动触发 Sparkle 检查 GitHub Releases 更新
- **设置**
  - 登录时启动（默认：开启）
  - 自动更新（默认：开启）
  - 语言 — 选择系统自动检测或 7 种语言之一
- **退出**

## CLI 选项

```bash
# 发送通知
open /Applications/ClaudeNotify.app --args \
  -title "Title" \
  -message "Body" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# 获取焦点窗口标题（需要辅助功能权限）
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# 获取焦点窗口 ID（需要辅助功能权限）
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-id <bundleId>

# 检查/请求辅助功能权限
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify --setup

# 请求 Terminal 自动化权限
open /Applications/ClaudeNotify.app --args --setup-terminal
```

### 参数说明

| 参数 | 描述 | 示例 |
|------|------|------|
| `-title` | 通知标题 | `Claude Code` |
| `-message` | 通知正文 | `Task complete — my-project` |
| `-sound` | 通知声音 | `default` |
| `-activate` | 点击时激活的应用 Bundle ID | `com.googlecode.iterm2` |
| `-workspace` | 项目路径（用于 Cursor/VS Code） | `/Users/me/project` |
| `-session` | 会话标识符（用于 iTerm/Terminal） | `w0t1p0:GUID` 或 `/dev/ttys001` |
| `-windowId` | 用于全屏 Space 切换的 CGWindowID:PID | `1181:31031` |

## 故障排除

### 通知不显示
- 检查系统设置 > 通知 > ClaudeNotify 是否设置为"横幅"或"提醒"

### 点击通知时出现"无法打开"错误
- **右键点击 → 打开**应用一次，或运行 `xattr -cr /Applications/ClaudeNotify.app`
- 运行 `open /Applications/ClaudeNotify.app` 检查辅助功能设置

### 重新构建后点击通知失效
- 重新构建会更改二进制文件的哈希值，导致辅助功能权限失效
- 在辅助功能设置中将 ClaudeNotify **关闭 → 开启**

### Terminal 标签页导航不工作
- 检查系统设置 > 自动化 > ClaudeNotify 是否已启用 Terminal
- 如果没有：`open /Applications/ClaudeNotify.app --args --setup-terminal`

### Warp：不支持全屏 Space 切换
- Warp 是基于 Rust 的应用，不响应 macOS SkyLight 私有 API
- 点击通知会激活 Warp，但无法切换到全屏 Space
- 解决方法：使用窗口模式或最大化（Option+绿色按钮）代替全屏

### VS Code 通知导航到了 iTerm 标签页
- 原因是 `ITERM_SESSION_ID` 环境变量泄漏到了 VS Code 终端中
- Hook 使用 `$__CFBundleIdentifier` 来区分应用，因此应能正常工作

## 架构

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist              # Bundle config + Sparkle keys
    ├── Frameworks/
    │   └── Sparkle.framework   # Auto-update framework
    ├── MacOS/
    │   └── ClaudeNotify        # Universal binary (arm64 + x86_64)
    └── Resources/
        ├── AppIcon.icns        # Bell icon
        ├── en.lproj/           # Localization markers
        ├── ko.lproj/
        └── ...

Source (SPM project):
├── Package.swift               # SPM + Sparkle dependency
├── Sources/ClaudeNotify/
│   ├── main.swift              # Entry point, CLI dispatch, IPC
│   ├── AppDelegate.swift       # Menu bar, notifications, Sparkle
│   ├── WindowActivation.swift  # SkyLight APIs
│   ├── NotificationPayload.swift
│   ├── NotificationHistory.swift
│   └── Localization.swift      # 7-language support
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── ClaudeNotify.entitlements
└── build.sh
```

**技术栈：**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- Sparkle 2（通过 GitHub Releases + EdDSA 签名自动更新）
- Swift Package Manager
- UNUserNotificationCenter（现代通知 API）
- SMAppService（登录项管理）
- DistributedNotificationCenter（CLI 与常驻应用间的 IPC）
- 菜单栏：NSStatusItem + SF Symbols（`bell.fill`）
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) 用于全屏 Space 切换
- Accessibility API (AXUIElement) 用于窗口检测
- AppleScript (NSAppleScript) 用于 iTerm/Terminal 标签页控制
- 使用 hardened runtime + Apple Events entitlement 进行代码签名

## 许可证

MIT
