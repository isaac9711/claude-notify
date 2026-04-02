# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | **中文** | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

一款 macOS 原生通知应用，专为 Claude Code 设计。在任务完成或需要输入时接收通知。

点击通知即可导航到 Claude Code 正在运行的**精确窗口和标签页**。

## 功能特性

- 原生 macOS 通知（`UNUserNotificationCenter`）
- 通知中显示源应用图标和项目名称
- 点击即可导航到精确的窗口/标签页：

| 环境 | 通知 | 点击导航 | 方式 |
|------|:----:|:--------:|------|
| iTerm | O | 窗口 + 标签页 | Session GUID |
| Cursor | O | 项目窗口 | 工作区路径 |
| VS Code | O | 项目窗口 | 工作区路径 |
| macOS Terminal | O | 窗口 + 标签页 | TTY 路径 |

## 系统要求

- macOS 14+（Sonoma 或更高版本）
- Swift 5.9+
- Claude Code CLI

## 安装

### 方式一：源码构建（推荐）

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### 方式二：预构建下载（DMG）

1. 从 [Releases](https://github.com/isaac9711/claude-notify/releases) 下载适用于您 macOS 版本的 DMG
2. 打开 DMG
3. 将 `ClaudeNotify.app` 拖入 `Applications` 文件夹
4. 首次启动时，如果出现安全警告，**右键点击 → 打开 → 打开**（仅需一次）

> **提示：** 您也可以在终端中运行 `xattr -cr /Applications/ClaudeNotify.app` 来跳过安全警告。

## 设置

### 1. macOS 权限

**辅助功能 + 通知（首次启动）：**
```bash
open /Applications/ClaudeNotify.app
```
- 辅助功能设置会自动打开。点击 `+` 并添加 ClaudeNotify
- 再次运行以触发通知权限对话框。允许即可

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
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"等待输入 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"任务完成 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ]
  }
}
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
    +-- 启动 ClaudeNotify.app
          |
          +-- 通过 UNUserNotificationCenter 发送通知
          +-- 附加源应用图标
          +-- 将 session/workspace 信息存储在 userInfo 中
```

### 点击导航流程

```
点击通知
    |
    +-- macOS 重新启动 ClaudeNotify
    +-- 调用 didReceive 处理器
    |
    +-- 判断会话类型：
          |
          +-- /dev/tty*  -> Terminal AppleScript（TTY 匹配）
          +-- w*t*p*:*   -> iTerm AppleScript（GUID 匹配）
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

### VS Code 通知导航到了 iTerm 标签页
- 原因是 `ITERM_SESSION_ID` 环境变量泄漏到了 VS Code 终端中
- Hook 使用 `$__CFBundleIdentifier` 来区分应用，因此应能正常工作

## 架构

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist          # Bundle ID: com.claude.notify
    ├── MacOS/
    │   └── ClaudeNotify    # 编译后的二进制文件
    └── Resources/
        └── AppIcon.icns    # 铃铛图标

~/.claude/settings.json     # Claude Code hook 配置文件
```

**技术栈：**
- Swift + Cocoa + UserNotifications + ApplicationServices
- UNUserNotificationCenter（现代通知 API）
- Accessibility API (AXUIElement) 用于窗口检测
- AppleScript (NSAppleScript) 用于 iTerm/Terminal 标签页控制
- 使用 hardened runtime + Apple Events entitlement 进行代码签名

## 许可证

MIT
