# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | **Tiếng Việt** | [Português](README.pt.md)

Ứng dụng thông báo macOS gốc dành cho Claude Code. Nhận thông báo khi tác vụ hoàn thành hoặc cần nhập liệu.

Nhấp vào thông báo để điều hướng đến **đúng cửa sổ và tab** nơi Claude Code đang chạy.

## Tính năng

- **Ứng dụng thường trú trên thanh menu** — biểu tượng chuông trên thanh menu, không có biểu tượng Dock
- **Tự động cập nhật qua Sparkle** — tự động kiểm tra GitHub Releases, cài đặt chỉ với một cú nhấp
- **Hỗ trợ đa ngôn ngữ** — 7 ngôn ngữ (en, ko, zh, ja, es, vi, pt) với tự động nhận diện ngôn ngữ hệ thống và chuyển đổi thủ công
- **Lịch sử thông báo** — lưu 10 thông báo gần nhất trong bộ nhớ, xem được từ thanh menu
- **Giao tiếp IPC** — khi ứng dụng đã chạy, thông báo mới được gửi qua `DistributedNotificationCenter` thay vì khởi chạy tiến trình mới
- **Khởi động cùng hệ thống** — bật mặc định, có thể tắt trong Cài đặt
- **Tự động cài đặt hook** — trình hướng dẫn khi khởi chạy lần đầu tự động cài đặt hook kèm xem trước thay đổi; phát hiện và nhắc cập nhật sau khi nâng cấp ứng dụng
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

Ứng dụng hỗ trợ **tự động cập nhật qua Sparkle** — nhấp "Kiểm tra cập nhật" trên thanh menu để cập nhật. Với bản biên dịch từ mã nguồn, chạy `git pull && ./build.sh`.

Sau mỗi lần cập nhật, hãy chuyển đổi ClaudeNotify **OFF → ON** trong Cài đặt Hệ thống > Trợ năng (thay đổi hash nhị phân sẽ vô hiệu hóa quyền).

> Cấu hình hook trong `~/.claude/settings.json` được giữ nguyên — không cần thay đổi.

## Thiết lập

### 1. Quyền trên macOS

**Khởi chạy ứng dụng (lần đầu tiên):**

Chỉ cần mở ClaudeNotify.app — nhấp đúp trong Finder hoặc mở qua Spotlight. Ứng dụng thường trú trên thanh menu và mặc định khởi động cùng hệ thống. Lần đầu khởi chạy sẽ tự động hiển thị yêu cầu cấp quyền Accessibility và Thông báo.

**Terminal Automation (nếu sử dụng Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Cho phép khi được hỏi "ClaudeNotify wants to control Terminal".

### 2. Cấu hình Hook cho Claude Code

#### Cài đặt tự động (khuyến nghị)

Khi khởi chạy lần đầu, ClaudeNotify hướng dẫn bạn chọn tệp `settings.json` và tự động cài đặt hook. Một bản xem trước thay đổi (diff) sẽ hiển thị chính xác những gì sẽ được thay đổi trước khi áp dụng. Bạn cũng có thể cài đặt hoặc gỡ cài đặt hook sau này từ thanh menu: **Cài đặt > Hook > Cài đặt/Gỡ cài đặt Hook, Đổi tệp cài đặt**.

#### Cài đặt thủ công

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
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); $N/Contents/MacOS/ClaudeNotify -title 'Claude Code' -message \"Chờ nhập liệu — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); $N/Contents/MacOS/ClaudeNotify -title 'Claude Code' -message \"Hoàn thành — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
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
Claude Code hook kích hoạt
    |
    +-- Nhận diện ứng dụng qua $__CFBundleIdentifier (iTerm, Cursor, VS Code, Terminal)
    +-- Lấy thông tin phiên:
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> đường dẫn tty qua ps
    |     Khác    -> (không có, dùng đường dẫn workspace)
    |
    +-- ClaudeNotify đã chạy chưa?
          |
          +-- CÓ -> gửi qua DistributedNotificationCenter (IPC)
          |          ứng dụng nhận payload → gửi UNUserNotification → cập nhật lịch sử
          |
          +-- CHƯA -> khởi chạy ClaudeNotify.app (thường trú trên thanh menu)
                       |
                       +-- Gửi thông báo qua UNUserNotificationCenter
                       +-- Đính kèm biểu tượng ứng dụng nguồn
                       +-- Lưu thông tin phiên/workspace vào lịch sử thông báo
```

### Luồng điều hướng khi nhấp

```
Nhấp vào thông báo
    |
    +-- Ứng dụng đã chạy (thường trú trên thanh menu)
    +-- Handler didReceive được gọi trực tiếp
    |
    +-- Xác định loại phiên:
          |
          +-- /dev/tty*  -> Terminal AppleScript (khớp tty)
          +-- w*t*p*:*   -> iTerm AppleScript (khớp GUID)
          +-- activate-only -> Warp (chỉ kích hoạt ứng dụng)
          +-- (khác)     -> open -b <bundleId> <workspace>
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

## Thanh menu

ClaudeNotify thường trú trên thanh menu với biểu tượng chuông (`􀋚`). Nhấp vào để truy cập:

- **Thông báo gần đây** — 10 thông báo gần nhất kèm tiêu đề, nội dung và thời gian; nhấp vào mục để điều hướng đến phiên đó
- **Kiểm tra cập nhật** — kích hoạt thủ công việc kiểm tra cập nhật Sparkle từ GitHub Releases
- **Cài đặt**
  - Khởi động cùng hệ thống (mặc định: BẬT)
  - Tự động cập nhật (mặc định: BẬT)
  - Ngôn ngữ — chọn tự động theo hệ thống hoặc một trong 7 ngôn ngữ
  - Hook > Cài đặt/Gỡ cài đặt Hook, Đổi tệp cài đặt
- **Thoát**

## Tùy chọn CLI

```bash
# Gửi thông báo
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  -title "Title" \
  -message "Body" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# Lấy tiêu đề cửa sổ đang focus (yêu cầu Accessibility)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# Lấy ID cửa sổ đang focus (yêu cầu Accessibility)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-id <bundleId>

# Kiểm tra/yêu cầu quyền Accessibility
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify --setup

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
    ├── Info.plist              # Bundle config + Sparkle keys
    ├── Frameworks/
    │   └── Sparkle.framework   # Auto-update framework
    ├── MacOS/
    │   └── ClaudeNotify        # Universal binary (arm64 + x86_64)
    └── Resources/
        ├── AppIcon.icns        # Biểu tượng chuông
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

**Công nghệ sử dụng:**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- Sparkle 2 (tự động cập nhật qua GitHub Releases + ký EdDSA)
- Swift Package Manager
- UNUserNotificationCenter (API thông báo hiện đại)
- SMAppService (quản lý mục khởi động)
- DistributedNotificationCenter (IPC giữa CLI và ứng dụng thường trú)
- Thanh menu: NSStatusItem + SF Symbols (`bell.fill`)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) để chuyển đổi fullscreen Space
- Accessibility API (AXUIElement) để phát hiện cửa sổ
- AppleScript (NSAppleScript) để điều khiển tab iTerm/Terminal
- Ký mã với hardened runtime + quyền Apple Events

## Giấy phép

MIT
