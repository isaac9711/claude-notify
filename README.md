# ClaudeNotify

**English** | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

A macOS native notification app for Claude Code. Get notified when tasks complete or input is needed.

Click a notification to navigate to the **exact window and tab** where Claude Code is running.

## Features

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

1. Download the new DMG (or `git pull && ./build.sh`)
2. Drag `ClaudeNotify.app` to `Applications` and replace the existing app
3. Toggle ClaudeNotify **OFF → ON** in System Settings > Accessibility (binary hash changes invalidate the permission)

> Hook configuration in `~/.claude/settings.json` is preserved — no changes needed.

## Setup

### 1. macOS Permissions

**Accessibility + Notifications (first launch):**
```bash
open /Applications/ClaudeNotify.app
```
- Accessibility settings will open automatically. Click `+` and add ClaudeNotify
- Run again to trigger the notification permission dialog. Allow it

**Terminal Automation (if using Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Allow when prompted with "ClaudeNotify wants to control Terminal".

### 2. Claude Code Hook Configuration

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
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Waiting for input — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Task complete — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ]
  }
}
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
    +-- Launch ClaudeNotify.app
          |
          +-- Send notification via UNUserNotificationCenter
          +-- Attach source app icon
          +-- Store session/workspace info in userInfo
```

### Click Navigation Flow

```
Notification clicked
    |
    +-- macOS relaunches ClaudeNotify
    +-- didReceive handler called
    |
    +-- Determine session type:
          |
          +-- /dev/tty*  -> Terminal AppleScript (tty matching)
          +-- w*t*p*:*   -> iTerm AppleScript (GUID matching)
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
    ├── Info.plist          # Bundle ID: com.claude.notify
    ├── MacOS/
    │   └── ClaudeNotify    # Compiled binary
    └── Resources/
        └── AppIcon.icns    # Bell icon

~/.claude/settings.json     # Claude Code hook configuration
```

**Tech Stack:**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- UNUserNotificationCenter (modern notification API)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) for fullscreen Space switching
- Accessibility API (AXUIElement) for window detection
- AppleScript (NSAppleScript) for iTerm/Terminal tab control
- Code signed with hardened runtime + Apple Events entitlement

## License

MIT
