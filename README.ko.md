# ClaudeNotify

[English](README.md) | **한국어** | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

Claude Code 작업 완료/입력 대기 시 macOS 네이티브 알림을 보내는 앱입니다.

알림 클릭 시 해당 터미널의 **정확한 창과 탭**으로 이동합니다.

## Features

- **메뉴 바 상주 앱** — 벨 아이콘이 메뉴 바에 항상 표시, Dock 아이콘 없음
- **Sparkle 자동 업데이트** — GitHub Releases를 자동으로 확인하고 클릭 한 번으로 설치
- **다국어 지원** — 7개 언어(en, ko, zh, ja, es, vi, pt), 시스템 언어 자동 감지 및 수동 선택 가능
- **알림 히스토리** — 최근 10건을 메모리에 저장, 메뉴 바에서 확인 가능
- **IPC 전달** — 앱이 이미 실행 중이면 `DistributedNotificationCenter`를 통해 새 알림 전달 (새 프로세스 실행 없음)
- **로그인 시 시작** — 기본값 ON, 설정에서 토글 가능
- **Hook 자동 설정** — 최초 실행 시 diff 미리보기와 함께 Hook을 자동 설치; 앱 업데이트 후 변경 감지 및 업데이트 안내
- macOS 네이티브 알림 (`UNUserNotificationCenter`)
- 알림에 소스 앱 아이콘 + 프로젝트명 표시
- 알림 클릭 시 정확한 창/탭으로 이동:

| 환경 | 알림 | 클릭 시 이동 | 전체화면 Space | 방식 |
|------|:----:|:----------:|:----------:|------|
| iTerm | O | 창 + 탭 | O | Session GUID + SkyLight API |
| Cursor | O | 프로젝트 창 | O | Workspace path + SkyLight API |
| VS Code | O | 프로젝트 창 | O | Workspace path + SkyLight API |
| macOS Terminal | O | 창 + 탭 | O | TTY path + SkyLight API |
| Warp | O | 앱 활성화 | X | open -b (Rust 앱 제한) |

## Requirements

- macOS 14+ (Sonoma 이상)
- Swift 5.9+
- Claude Code CLI

## Installation

### Option 1: Pre-built Download (DMG)

1. [Releases](https://github.com/isaac9711/claude-notify/releases)에서 macOS 버전에 맞는 DMG 다운로드
2. DMG 열기
3. `ClaudeNotify.app`을 `Applications` 폴더로 드래그
4. 첫 실행 시 보안 경고가 뜨면 **우클릭 → 열기 → 열기** 클릭 (최초 1회)

> **Tip:** 또는 터미널에서 `xattr -cr /Applications/ClaudeNotify.app` 실행하면 보안 경고 없이 사용할 수 있습니다.

### Option 2: Source Build

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Upgrade (업그레이드)

앱은 **Sparkle 자동 업데이트**를 지원합니다 — 메뉴 바에서 "업데이트 확인"을 클릭하면 업데이트할 수 있습니다. 소스 빌드의 경우 `git pull && ./build.sh`를 실행하세요.

업데이트 후에는 시스템 설정 > 손쉬운 사용에서 ClaudeNotify를 **OFF → ON** 토글해야 합니다 (바이너리 해시 변경으로 권한 재설정 필요).

> `~/.claude/settings.json`의 Hook 설정은 유지됩니다.

## Setup

### 1. macOS 권한 설정

**앱 실행 (최초 실행):**

ClaudeNotify.app을 실행하기만 하면 됩니다 — Finder에서 더블클릭하거나 Spotlight로 열면 됩니다. 앱은 메뉴 바에 상주하며 기본적으로 로그인 시 자동 시작됩니다. 최초 실행 시 손쉬운 사용 및 알림 권한 요청 팝업이 자동으로 나타납니다.

**Terminal 자동화 권한 (Terminal.app 사용 시):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
"ClaudeNotify가 Terminal을 제어하려고 합니다" 팝업이 뜨면 허용합니다.

### 2. Claude Code Hook 설정

#### 자동 설정 (권장)

최초 실행 시 ClaudeNotify가 `settings.json` 파일 선택을 안내하고 Hook을 자동으로 설치합니다. 적용 전에 변경 내용을 diff로 미리 확인할 수 있습니다. 이후에도 메뉴 바에서 Hook을 설치하거나 제거할 수 있습니다: **설정 > Hook > 훅 설치/제거, 설정 파일 변경**.

#### 수동 설정

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
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); $N/Contents/MacOS/ClaudeNotify -title 'Claude Code' -message \"입력 대기 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); $N/Contents/MacOS/ClaudeNotify -title 'Claude Code' -message \"작업 완료 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Git Worktree 워크스페이스 경로 설정

기본 Hook은 `git rev-parse --git-common-dir`를 사용하여 항상 **베이스 프로젝트 루트**로 해석합니다. 이를 통해 Claude Code가 worktree를 생성할 때 새 창이 열리는 것을 방지합니다.

| 시나리오 | 기본값 (git common dir) | 대안 (git show-toplevel) |
|----------|:---:|:---:|
| 베이스 프로젝트 창 | 베이스 창으로 이동 ✓ | 베이스 창으로 이동 ✓ |
| Worktree 창 (별도로 열린 경우) | 베이스 창으로 이동 | Worktree 창으로 이동 ✓ |
| Claude Code가 생성한 worktree (창 없음) | 베이스 창으로 이동 ✓ | 새 창 생성 |

주로 worktree를 별도의 Cursor/VS Code 창으로 열어 작업하는 경우, Hook의 workspace 부분을 다음과 같이 교체하세요:

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
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
    +-- ClaudeNotify가 이미 실행 중?
          |
          +-- YES -> DistributedNotificationCenter로 IPC 전달
          |            앱이 페이로드 수신 → UNUserNotification 전송 → 히스토리 업데이트
          |
          +-- NO  -> ClaudeNotify.app 실행 (메뉴 바에 상주)
                       |
                       +-- UNUserNotificationCenter로 알림 전송
                       +-- 알림에 소스 앱 아이콘 첨부
                       +-- 알림 히스토리에 세션/workspace 정보 저장
```

### Click Navigation Flow

```
알림 클릭
    |
    +-- 앱이 이미 실행 중 (메뉴 바 상주)
    +-- didReceive 핸들러가 직접 호출됨
    |
    +-- 세션 타입 판별:
          |
          +-- /dev/tty*  -> Terminal AppleScript (tty 매칭)
          +-- w*t*p*:*   -> iTerm AppleScript (GUID 매칭)
          +-- activate-only -> Warp (앱 활성화만)
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

## 메뉴 바

ClaudeNotify는 메뉴 바에 벨 아이콘(`􀋚`)으로 상주합니다. 클릭하면 다음 항목에 접근할 수 있습니다:

- **최근 알림** — 제목, 메시지, 시각을 포함한 최근 10건; 항목 클릭 시 해당 세션으로 이동
- **업데이트 확인** — GitHub Releases를 대상으로 Sparkle 업데이트 수동 확인
- **설정**
  - 로그인 시 시작 (기본값: ON)
  - 자동 업데이트 (기본값: ON)
  - 언어 — 시스템 자동 감지 또는 7개 언어 중 선택
  - 훅 > 훅 설치/제거, 설정 파일 변경
- **종료**

## CLI Options

```bash
# 알림 전송
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  -title "제목" \
  -message "내용" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# 현재 포커스된 창 제목 조회 (Accessibility 필요)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# 현재 포커스된 창 ID 조회 (Accessibility 필요)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-id <bundleId>

# Accessibility 권한 확인/요청
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify --setup

# Terminal 자동화 권한 요청
open /Applications/ClaudeNotify.app --args --setup-terminal
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
| `-windowId` | 전체화면 Space 전환을 위한 CGWindowID:PID | `1181:31031` |

## Troubleshooting

### 알림이 안 뜸
- 시스템 설정 > 알림 > ClaudeNotify 항목에서 알림이 "배너" 또는 "알림"으로 설정되어 있는지 확인

### 알림 클릭 시 "열 수 없습니다" 에러
- **우클릭 → 열기**로 한 번 실행하거나, `xattr -cr /Applications/ClaudeNotify.app` 실행
- `open /Applications/ClaudeNotify.app`으로 손쉬운 사용 설정 확인

### 재빌드 후 알림 클릭이 안 됨
- 빌드 시 바이너리 해시가 변경되어 손쉬운 사용 권한이 무효화됩니다
- 손쉬운 사용에서 ClaudeNotify를 **OFF → ON** 토글해주세요

### Terminal 탭 이동이 안 됨
- 시스템 설정 > 자동화 > ClaudeNotify에 Terminal이 허용되어 있는지 확인
- 없으면: `open /Applications/ClaudeNotify.app --args --setup-terminal` 실행

### Warp: 전체화면 Space 전환 미지원
- Warp는 Rust 기반 앱으로 macOS SkyLight private API에 응답하지 않습니다
- 알림 클릭 시 Warp가 활성화되지만 전체화면 Space로 전환할 수 없습니다
- 우회 방법: 전체화면 대신 창모드 또는 최대화(Option+초록 버튼) 사용

### VS Code에서 iTerm 탭으로 이동됨
- VS Code 터미널에 `ITERM_SESSION_ID` 환경변수가 남아있는 경우 발생
- Hook이 `$__CFBundleIdentifier`로 앱을 구분하도록 설정되어 있으면 정상 동작합니다

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
- Sparkle 2 (GitHub Releases 자동 업데이트 + EdDSA 서명)
- Swift Package Manager
- UNUserNotificationCenter (modern notification API)
- SMAppService (로그인 항목 관리)
- DistributedNotificationCenter (CLI와 상주 앱 간 IPC)
- 메뉴 바: NSStatusItem + SF Symbols (`bell.fill`)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) for fullscreen Space switching
- Accessibility API (AXUIElement) for window detection
- AppleScript (NSAppleScript) for iTerm/Terminal tab control
- Code signed with hardened runtime + Apple Events entitlement

## License

MIT
