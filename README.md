# ClaudeNotify

**English** | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

A macOS native notification app for Claude Code. Get notified when tasks complete or input is needed.

Click a notification to navigate to the **exact window and tab** where Claude Code is running.

## Features

- **Menu bar resident app** — bell icon lives in your menu bar, no Dock icon
- **Auto-update via Sparkle** — checks GitHub Releases automatically, installs with one click
- **Multi-language support** — 7 languages (en, ko, zh, ja, es, vi, pt) with system auto-detection and manual override
- **Notification history** — last 10 notifications stored in memory, viewable from the menu bar
- **IPC delivery** — when the app is already running, new notifications arrive via `DistributedNotificationCenter` instead of launching a new process
- **Launch at Login** — enabled by default, toggleable in Settings
- **Automatic hook setup** — first-launch wizard installs hooks with a diff preview; detects and prompts for updates after app upgrades
- Native macOS notifications (`UNUserNotificationCenter`)
- Source app icon + project name displayed in notification
- Click-to-navigate to the exact window/tab:

| Environment | Notification | Click Navigation | Fullscreen Space | Method |
|-------------|:----:|:----------:|:----------:|--------|
| iTerm | O | Window + Tab | O | Session GUID + SkyLight API |
| Cursor | O | Project Window | O | Workspace path + SkyLight API |
| VS Code | O | Project Window | O | Workspace path + SkyLight API |
| macOS Terminal | O | Window + Tab | O | TTY path + SkyLight API |
| Warp | O | App Activate | X | open -b (Rust app limitation) |

## Requirements

- macOS 14+ (Sonoma or later)
- Swift 5.9+
- Claude Code CLI

## Installation

### Option 1: Pre-built Download (DMG)

1. Download the DMG for your macOS version from [Releases](https://github.com/isaac9711/claude-notify/releases)
2. Open the DMG
3. Drag `ClaudeNotify.app` to the `Applications` folder
4. On first launch, if a security warning appears, **Right-click → Open → Open** (one-time only)

> **Tip:** Alternatively, run `xattr -cr /Applications/ClaudeNotify.app` in Terminal to skip the security warning.

### Option 2: Source Build

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Upgrade

The app supports **auto-update via Sparkle** — click "Check for Updates" in the menu bar to update. For source builds, run `git pull && ./build.sh`.

After any update, toggle ClaudeNotify **OFF → ON** in System Settings > Accessibility (binary hash changes invalidate the permission).

> Hook configuration in `~/.claude/settings.json` is preserved — no changes needed.

## Setup

### 1. macOS Permissions

**Launch the app (first time):**

Simply launch ClaudeNotify.app — double-click it in Finder or open it via Spotlight. The app stays resident in the menu bar and starts at login by default. First launch automatically triggers Accessibility and Notification permission prompts.

**Terminal Automation (if using Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Allow when prompted with "ClaudeNotify wants to control Terminal".

### 2. Claude Code Hook Configuration

#### Automatic Setup (Recommended)

On first launch, ClaudeNotify prompts you to select your `settings.json` file and installs hooks automatically. A diff preview shows exactly what will be changed before applying. You can also install or uninstall hooks later from the menu bar: **Settings > Hook > Install/Uninstall Hooks, Change Settings File**.

#### Manual Setup

Add to the `hooks` section of `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Waiting for input — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Task complete — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Workspace Resolution for Git Worktrees

The default hook uses `git rev-parse --git-common-dir` to always resolve to the **base project root**. This prevents new windows from opening when Claude Code creates worktrees.

| Scenario | Default (git common dir) | Alternative (git show-toplevel) |
|----------|:---:|:---:|
| Base project window | Goes to base window ✓ | Goes to base window ✓ |
| Worktree window (opened separately) | Goes to base window | Goes to worktree window ✓ |
| Worktree created by Claude Code (no window) | Goes to base window ✓ | Creates new window |

If you primarily work with worktrees opened as separate Cursor/VS Code windows, replace the workspace part in your hooks:

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
```
```

## How It Works

### Notification Flow

```
Claude Code hook fires
    |
    +-- Identify app via $__CFBundleIdentifier (iTerm, Cursor, VS Code, Terminal)
    +-- Capture session info:
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> tty path via ps
    |     Others  -> (none, uses workspace path)
    |
    +-- Is ClaudeNotify already running?
          |
          +-- YES -> deliver via DistributedNotificationCenter (IPC)
          |            app receives payload, sends UNUserNotification, updates history
          |
          +-- NO  -> launch ClaudeNotify.app (stays resident in menu bar)
                       |
                       +-- Send notification via UNUserNotificationCenter
                       +-- Attach source app icon
                       +-- Store session/workspace info in notification history
```

### Click Navigation Flow

```
Notification clicked
    |
    +-- App already running (menu bar resident)
    +-- didReceive handler called directly
    |
    +-- Determine session type:
          |
          +-- /dev/tty*  -> Terminal AppleScript (tty matching)
          +-- w*t*p*:*   -> iTerm AppleScript (GUID matching)
          +-- activate-only -> Warp (app activate only)
          +-- (other)    -> open -b <bundleId> <workspace>
```

### Per-Terminal Navigation

**iTerm:**
- Extracts session GUID from `ITERM_SESSION_ID`
- AppleScript iterates all windows/tabs/sessions to find matching GUID
- Selects matching window + tab

**macOS Terminal:**
- Gets parent process TTY path via `ps -o tty= -p $PPID`
- AppleScript iterates all windows/tabs to match TTY
- Sets matched tab as selected, brings window to front

**Cursor / VS Code:**
- Passes `$PWD` (working directory) as workspace path
- `open -b <bundleId> <workspace>` activates the project window
- Each project has its own window, ensuring accurate navigation

## Menu Bar

ClaudeNotify lives in the menu bar as a bell icon (`􀋚`). Click it to access:

- **Recent Notifications** — last 10 notifications with title, message, and timestamp; click any entry to navigate to that session
- **Check for Updates** — manually trigger a Sparkle update check against GitHub Releases
- **Settings**
  - Launch at Login (default: ON)
  - Auto Updates (default: ON)
  - Language — choose from system auto-detect or one of 7 languages
  - Hook > Install/Uninstall Hooks, Change Settings File
- **Quit**

## CLI Options

```bash
# Send notification
open /Applications/ClaudeNotify.app --args \
  -title "Title" \
  -message "Body" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# Get focused window title (requires Accessibility)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# Get focused window ID (requires Accessibility)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-id <bundleId>

# Check/request Accessibility permission
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify --setup

# Request Terminal automation permission
open /Applications/ClaudeNotify.app --args --setup-terminal
```

### Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-title` | Notification title | `Claude Code` |
| `-message` | Notification body | `Task complete — my-project` |
| `-sound` | Notification sound | `default` |
| `-activate` | Bundle ID of app to activate on click | `com.googlecode.iterm2` |
| `-workspace` | Project path (for Cursor/VS Code) | `/Users/me/project` |
| `-session` | Session identifier (for iTerm/Terminal) | `w0t1p0:GUID` or `/dev/ttys001` |
| `-windowId` | CGWindowID:PID for fullscreen Space switching | `1181:31031` |

## Troubleshooting

### Notifications not showing
- Check System Settings > Notifications > ClaudeNotify is set to "Banners" or "Alerts"

### "Cannot be opened" error on notification click
- **Right-click → Open** the app once, or run `xattr -cr /Applications/ClaudeNotify.app`
- Run `open /Applications/ClaudeNotify.app` to check Accessibility settings

### Notification click stops working after rebuild
- Rebuild changes the binary hash, invalidating Accessibility permission
- Toggle ClaudeNotify **OFF → ON** in Accessibility settings

### Terminal tab navigation not working
- Check System Settings > Automation > ClaudeNotify has Terminal enabled
- If not: `open /Applications/ClaudeNotify.app --args --setup-terminal`

### Warp: fullscreen Space switching not working
- Warp is a Rust-based app that doesn't respond to macOS SkyLight private API
- Notification click will activate Warp but cannot switch to a fullscreen Space
- Workaround: use windowed mode or maximize (Option+Green button) instead of fullscreen

### VS Code notification navigates to iTerm tab
- Caused by `ITERM_SESSION_ID` env var leaking into VS Code terminal
- Hook uses `$__CFBundleIdentifier` to distinguish apps, so this should work correctly

## Architecture

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

**Tech Stack:**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- Sparkle 2 (auto-update via GitHub Releases + EdDSA signing)
- Swift Package Manager
- UNUserNotificationCenter (modern notification API)
- SMAppService (login item management)
- DistributedNotificationCenter (IPC between CLI and resident app)
- Menu bar: NSStatusItem + SF Symbols (`bell.fill`)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) for fullscreen Space switching
- Accessibility API (AXUIElement) for window detection
- AppleScript (NSAppleScript) for iTerm/Terminal tab control
- Code signed with hardened runtime + Apple Events entitlement

## License

MIT
