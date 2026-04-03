# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | **Tiếng Việt** | [Português](README.pt.md)

Ứng dụng thông báo macOS gốc dành cho Claude Code. Nhận thông báo khi tác vụ hoàn thành hoặc cần nhập liệu.

Nhấp vào thông báo để điều hướng đến **đúng cửa sổ và tab** nơi Claude Code đang chạy.

## Tính năng

- Thông báo macOS gốc (`UNUserNotificationCenter`)
- Hiển thị biểu tượng ứng dụng nguồn + tên dự án trong thông báo
- Nhấp để điều hướng đến đúng cửa sổ/tab:

| Môi trường | Thông báo | Điều hướng khi nhấp | Phương thức |
|-------------|:----:|:----------:|--------|
| iTerm | O | Cửa sổ + Tab | Session GUID |
| Cursor | O | Cửa sổ dự án | Workspace path |
| VS Code | O | Cửa sổ dự án | Workspace path |
| macOS Terminal | O | Cửa sổ + Tab | TTY path |

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
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Chờ nhập liệu — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Hoàn thành — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ]
  }
}
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
- Swift + Cocoa + UserNotifications + ApplicationServices
- UNUserNotificationCenter (API thông báo hiện đại)
- Accessibility API (AXUIElement) để phát hiện cửa sổ
- AppleScript (NSAppleScript) để điều khiển tab iTerm/Terminal
- Ký mã với hardened runtime + quyền Apple Events

## Giấy phép

MIT
