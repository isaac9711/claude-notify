# ClaudeNotify

Claude Code 작업 완료/입력 대기 시 macOS 네이티브 알림을 보내는 앱입니다.

알림 클릭 시 해당 터미널의 **정확한 창과 탭**으로 이동합니다.

## Features

- macOS 네이티브 알림 (`UNUserNotificationCenter`)
- 알림에 소스 앱 아이콘 + 프로젝트명 표시
- 알림 클릭 시 정확한 창/탭으로 이동:

| 환경 | 알림 | 클릭 시 이동 | 방식 |
|------|:----:|:----------:|------|
| iTerm | O | 창 + 탭 | Session GUID |
| Cursor | O | 프로젝트 창 | Workspace path |
| VS Code | O | 프로젝트 창 | Workspace path |
| macOS Terminal | O | 창 + 탭 | TTY path |

## Requirements

- macOS 14+ (Sonoma 이상)
- Swift 5.9+
- Claude Code CLI

## Installation

### Option 1: Source Build (recommended)

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Option 2: Pre-built Download

1. [Releases](https://github.com/isaac9711/claude-notify/releases)에서 `ClaudeNotify.zip` 다운로드
2. 압축 해제 후 `ClaudeNotify.app`을 `~/.claude/`로 이동
3. Gatekeeper 우회:
```bash
xattr -cr ~/.claude/ClaudeNotify.app
```

## Setup

### 1. macOS 권한 설정

**손쉬운 사용 (필수):**
- 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용
- `+` 버튼 > `~/.claude/ClaudeNotify.app` 추가 (Cmd+Shift+G로 경로 입력)

**알림 허용 (첫 실행 시 자동):**
```bash
open ~/.claude/ClaudeNotify.app --args -title "Test" -message "Setup" -sound default
```
알림 권한 팝업이 뜨면 허용합니다.

**Terminal 자동화 권한 (Terminal.app 사용 시):**
```bash
open ~/.claude/ClaudeNotify.app --args --setup-terminal
```
"ClaudeNotify가 Terminal을 제어하려고 합니다" 팝업이 뜨면 허용합니다.

### 2. Claude Code Hook 설정

`~/.claude/settings.json`의 `hooks` 섹션에 추가:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open ~/.claude/ClaudeNotify.app --args -title 'Claude Code' -message \"입력 대기 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open ~/.claude/ClaudeNotify.app --args -title 'Claude Code' -message \"작업 완료 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
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
Claude Code hook 실행
    |
    +-- $__CFBundleIdentifier 로 앱 식별 (iTerm, Cursor, VS Code, Terminal)
    +-- 세션 정보 캡처:
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> tty path via ps
    |     Others  -> (없음, workspace 경로 사용)
    |
    +-- ClaudeNotify.app 실행
          |
          +-- UNUserNotificationCenter로 알림 전송
          +-- 알림에 소스 앱 아이콘 첨부
          +-- userInfo에 세션/workspace 정보 저장
```

### Click Navigation Flow

```
알림 클릭
    |
    +-- macOS가 ClaudeNotify 재실행
    +-- didReceive 핸들러 호출
    |
    +-- 세션 타입 판별:
          |
          +-- /dev/tty*  -> Terminal AppleScript (tty 매칭)
          +-- w*t*p*:*   -> iTerm AppleScript (GUID 매칭)
          +-- (그 외)     -> open -b <bundleId> <workspace>
```

### Terminal별 동작 원리

**iTerm:**
- `ITERM_SESSION_ID` 환경변수에서 세션 GUID 추출
- AppleScript로 모든 윈도우/탭/세션을 순회하여 GUID 매칭
- 매칭된 윈도우 select + 탭 select

**macOS Terminal:**
- `ps -o tty= -p $PPID`로 부모 프로세스의 TTY 경로 획득
- AppleScript로 모든 윈도우/탭을 순회하여 TTY 매칭
- 매칭된 탭 selected = true, 윈도우 index = 1

**Cursor / VS Code:**
- `$PWD`(작업 디렉토리)를 workspace 경로로 전달
- `open -b <bundleId> <workspace>` 로 해당 프로젝트 창 활성화
- 각 프로젝트가 별도 창이므로 정확한 창으로 이동

## CLI Options

```bash
# 알림 전송
open ~/.claude/ClaudeNotify.app --args \
  -title "제목" \
  -message "내용" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# 현재 포커스된 창 제목 조회 (Accessibility 필요)
~/.claude/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# Terminal 자동화 권한 요청
open ~/.claude/ClaudeNotify.app --args --setup-terminal
```

### Parameters

| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `-title` | 알림 제목 | `Claude Code` |
| `-message` | 알림 본문 | `작업 완료 — my-project` |
| `-sound` | 알림 사운드 | `default` |
| `-activate` | 클릭 시 활성화할 앱 Bundle ID | `com.googlecode.iterm2` |
| `-workspace` | 프로젝트 경로 (Cursor/VS Code용) | `/Users/me/project` |
| `-session` | 세션 식별자 (iTerm/Terminal용) | `w0t1p0:GUID` 또는 `/dev/ttys001` |

## Troubleshooting

### 알림이 안 뜸
- 시스템 설정 > 알림 > ClaudeNotify 항목에서 알림이 "배너" 또는 "알림"으로 설정되어 있는지 확인

### 알림 클릭 시 "열 수 없습니다" 에러
- `xattr -cr ~/.claude/ClaudeNotify.app` 실행
- 시스템 설정 > 손쉬운 사용에 ClaudeNotify가 추가/활성화되어 있는지 확인

### 재빌드 후 알림 클릭이 안 됨
- 빌드 시 바이너리 해시가 변경되어 손쉬운 사용 권한이 무효화됩니다
- 손쉬운 사용에서 ClaudeNotify를 **OFF → ON** 토글해주세요

### Terminal 탭 이동이 안 됨
- 시스템 설정 > 자동화 > ClaudeNotify에 Terminal이 허용되어 있는지 확인
- 없으면: `open ~/.claude/ClaudeNotify.app --args --setup-terminal` 실행

### VS Code에서 iTerm 탭으로 이동됨
- VS Code 터미널에 `ITERM_SESSION_ID` 환경변수가 남아있는 경우 발생
- Hook이 `$__CFBundleIdentifier`로 앱을 구분하도록 설정되어 있으면 정상 동작합니다

## Architecture

```
~/.claude/
├── ClaudeNotify.app/
│   └── Contents/
│       ├── Info.plist          # Bundle ID: com.claude.notify
│       ├── MacOS/
│       │   └── ClaudeNotify    # Compiled binary
│       └── Resources/
│           └── AppIcon.icns    # Bell icon
└── settings.json               # Claude Code hook configuration
```

**Tech Stack:**
- Swift + Cocoa + UserNotifications + ApplicationServices
- UNUserNotificationCenter (modern notification API)
- Accessibility API (AXUIElement) for window detection
- AppleScript (NSAppleScript) for iTerm/Terminal tab control
- Code signed with hardened runtime + Apple Events entitlement

## License

MIT
