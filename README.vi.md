# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | **Tiếng Việt** | [Português](README.pt.md)

Ứng dụng thông báo macOS gốc dành cho Claude Code. Nhận thông báo khi tác vụ hoàn thành hoặc cần nhập liệu.

Nhấp vào thông báo để điều hướng đến **đúng cửa sổ và tab** nơi Claude Code đang chạy.

## Tính năng

- Thông báo macOS gốc (`UNUserNotificationCenter`)
- Hiển thị biểu tượng ứng dụng nguồn + tên dự án trong thông báo
- Nhấp để điều hướng đến đúng cửa sổ/tab:

| Môi trường | Thông báo | Điều hướng khi nhấp | Fullscreen Space | Phương thức |
|------------|:----:|:----------:|:----------:|--------|
| iTerm | O | Cửa sổ + Tab | O | Session GUID + SkyLight API |
| Cursor | O | Cửa sổ dự án | O | Workspace path + SkyLight API |
| VS Code | O | Cửa sổ dự án | O | Workspace path + SkyLight API |
| macOS Terminal | O | Cửa sổ + Tab | O | TTY path + SkyLight API |
| Warp | O | Kích hoạt ứng dụng | X | open -b (giới hạn ứng dụng Rust) |

## Yêu cầu

- macOS 14+ (Sonoma trở lên)
- Swift 5.9+
- Claude Code CLI

## Cài đặt

### Cách 1: Tải bản dựng sẵn (DMG)

1. Tải tệp DMG phù hợp với phiên bản macOS của bạn từ [Releases](https://github.com/isaac9711/claude-notify/releases)
2. Mở tệp DMG
3. Kéo `ClaudeNotify.app` vào thư mục `Applications`
4. Khi khởi chạy lần đầu, nếu xuất hiện cảnh báo bảo mật, hãy **Nhấp chuột phải → Open → Open** (chỉ cần một lần)

> **Mẹo:** Hoặc chạy `xattr -cr /Applications/ClaudeNotify.app` trong Terminal để bỏ qua cảnh báo bảo mật.

### Cách 2: Biên dịch từ mã nguồn

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Nâng cấp

1. Tải DMG mới (hoặc `git pull && ./build.sh`)
2. Kéo `ClaudeNotify.app` vào `Applications` và thay thế ứng dụng hiện có
3. Chuyển đổi ClaudeNotify **OFF → ON** trong Cài đặt Hệ thống > Trợ năng (thay đổi hash nhị phân sẽ vô hiệu hóa quyền)

> Cấu hình hook trong `~/.claude/settings.json` được giữ nguyên — không cần thay đổi.

## Thiết lập

### 1. Quyền trên macOS

**Accessibility + Notifications (lần khởi chạy đầu tiên):**
```bash
open /Applications/ClaudeNotify.app
```
- Cài đặt Accessibility sẽ tự động mở. Nhấp `+` và thêm ClaudeNotify
- Chạy lại để kích hoạt hộp thoại cấp quyền thông báo. Cho phép

**Terminal Automation (nếu sử dụng Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Cho phép khi được hỏi "ClaudeNotify wants to control Terminal".

### 2. Cấu hình Hook cho Claude Code

Thêm vào phần `hooks` của `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Chờ nhập liệu — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Hoàn thành — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Cấu hình đường dẫn workspace cho Git Worktrees

Hook mặc định sử dụng `git rev-parse --git-common-dir` để luôn trỏ về **thư mục gốc của dự án cơ sở**. Điều này ngăn việc mở cửa sổ mới khi Claude Code tạo worktree.

| Tình huống | Mặc định (git common dir) | Thay thế (git show-toplevel) |
|----------|:---:|:---:|
| Cửa sổ dự án cơ sở | Chuyển đến cửa sổ cơ sở ✓ | Chuyển đến cửa sổ cơ sở ✓ |
| Cửa sổ worktree (mở riêng) | Chuyển đến cửa sổ cơ sở | Chuyển đến cửa sổ worktree ✓ |
| Worktree do Claude Code tạo (không có cửa sổ) | Chuyển đến cửa sổ cơ sở ✓ | Tạo cửa sổ mới |

Nếu bạn chủ yếu làm việc với worktree được mở dưới dạng cửa sổ Cursor/VS Code riêng biệt, hãy thay thế phần workspace trong hook:

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
```

## Cách hoạt động

### Luồng thông báo

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

### Luồng điều hướng khi nhấp

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

### Điều hướng theo từng Terminal

**iTerm:**
- Trích xuất session GUID từ `ITERM_SESSION_ID`
- AppleScript duyệt qua tất cả cửa sổ/tab/phiên để tìm GUID phù hợp
- Chọn đúng cửa sổ + tab

**macOS Terminal:**
- Lấy đường dẫn TTY của tiến trình cha qua `ps -o tty= -p $PPID`
- AppleScript duyệt qua tất cả cửa sổ/tab để khớp TTY
- Đặt tab khớp làm tab được chọn, đưa cửa sổ lên phía trước

**Cursor / VS Code:**
- Truyền `$PWD` (thư mục làm việc) làm workspace path
- `open -b <bundleId> <workspace>` kích hoạt cửa sổ dự án
- Mỗi dự án có cửa sổ riêng, đảm bảo điều hướng chính xác

## Tùy chọn CLI

```bash
# Gửi thông báo
open /Applications/ClaudeNotify.app --args \
  -title "Title" \
  -message "Body" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# Lấy tiêu đề cửa sổ đang focus (yêu cầu Accessibility)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# Yêu cầu quyền tự động hóa Terminal
open /Applications/ClaudeNotify.app --args --setup-terminal
```

### Tham số

| Tham số | Mô tả | Ví dụ |
|-----------|-------------|---------|
| `-title` | Tiêu đề thông báo | `Claude Code` |
| `-message` | Nội dung thông báo | `Task complete — my-project` |
| `-sound` | Âm thanh thông báo | `default` |
| `-activate` | Bundle ID của ứng dụng cần kích hoạt khi nhấp | `com.googlecode.iterm2` |
| `-workspace` | Đường dẫn dự án (cho Cursor/VS Code) | `/Users/me/project` |
| `-session` | Mã phiên (cho iTerm/Terminal) | `w0t1p0:GUID` hoặc `/dev/ttys001` |
| `-windowId` | CGWindowID:PID để chuyển đổi fullscreen Space | `1181:31031` |

## Xử lý sự cố

### Thông báo không hiển thị
- Kiểm tra System Settings > Notifications > ClaudeNotify được đặt thành "Banners" hoặc "Alerts"

### Lỗi "Cannot be opened" khi nhấp thông báo
- **Nhấp chuột phải → Open** ứng dụng một lần, hoặc chạy `xattr -cr /Applications/ClaudeNotify.app`
- Chạy `open /Applications/ClaudeNotify.app` để kiểm tra cài đặt Accessibility

### Nhấp thông báo ngừng hoạt động sau khi biên dịch lại
- Việc biên dịch lại thay đổi hash của binary, làm vô hiệu hóa quyền Accessibility
- Bật/tắt ClaudeNotify **OFF → ON** trong cài đặt Accessibility

### Điều hướng tab Terminal không hoạt động
- Kiểm tra System Settings > Automation > ClaudeNotify đã bật Terminal
- Nếu chưa: `open /Applications/ClaudeNotify.app --args --setup-terminal`

### Warp: không hỗ trợ chuyển đổi fullscreen Space
- Warp là ứng dụng dựa trên Rust, không phản hồi SkyLight private API của macOS
- Nhấp vào thông báo sẽ kích hoạt Warp nhưng không thể chuyển đổi sang fullscreen Space
- Giải pháp: sử dụng chế độ cửa sổ hoặc phóng to (Option+nút xanh) thay vì fullscreen

### Thông báo VS Code điều hướng đến tab iTerm
- Nguyên nhân do biến môi trường `ITERM_SESSION_ID` bị rò rỉ vào terminal của VS Code
- Hook sử dụng `$__CFBundleIdentifier` để phân biệt ứng dụng, nên vấn đề này sẽ được xử lý đúng

## Kiến trúc

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist          # Bundle ID: com.claude.notify
    ├── MacOS/
    │   └── ClaudeNotify    # Binary đã biên dịch
    └── Resources/
        └── AppIcon.icns    # Biểu tượng chuông

~/.claude/settings.json     # Cấu hình hook của Claude Code
```

**Công nghệ sử dụng:**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- UNUserNotificationCenter (API thông báo hiện đại)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) for fullscreen Space switching
- Accessibility API (AXUIElement) để phát hiện cửa sổ
- AppleScript (NSAppleScript) để điều khiển tab iTerm/Terminal
- Ký mã với hardened runtime + quyền Apple Events

## Giấy phép

MIT
