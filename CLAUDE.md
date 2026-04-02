# ClaudeNotify

macOS용 Claude Code 알림 앱. Swift + Cocoa + UNUserNotificationCenter 기반.

## Build

```bash
./build.sh
```

빌드 결과물: `/Applications/ClaudeNotify.app`

재빌드 후 반드시 시스템 설정 > 손쉬운 사용에서 ClaudeNotify를 OFF → ON 토글해야 함 (바이너리 해시 변경으로 인한 권한 무효화).

## Architecture

- `ClaudeNotify.swift` — 단일 소스 파일
- `Info.plist` — 앱 번들 설정 (Bundle ID: `com.claude.notify`, LSUIElement: true)
- `ClaudeNotify.entitlements` — hardened runtime + Apple Events 권한
- `AppIcon.icns` — 벨 아이콘
- `build.sh` — 빌드 + 코드서명 + LaunchServices 등록

## CLI Modes

앱은 여러 모드로 동작:

1. **알림 전송** (기본): `open ClaudeNotify.app --args -title ... -message ... -activate ... -workspace ... -session ...`
2. **창 제목 조회**: `ClaudeNotify --get-window-title <bundleId>` — AX API로 포커스된 창 제목 반환
3. **Terminal 권한 요청**: `open ClaudeNotify.app --args --setup-terminal` — Terminal 자동화 권한 팝업 트리거
4. **Terminal 탭 전환**: `ClaudeNotify --raise-terminal <tty>` — 내부용, 알림 클릭 시 호출

## Click Navigation Logic

`didReceive` 핸들러에서 session 파라미터로 분기:

- `/dev/tty*` → macOS Terminal: `osascript`로 tty 매칭하여 탭 선택
- `w*t*p*:GUID` → iTerm: `NSAppleScript`로 GUID 매칭하여 세션 선택
- 그 외 → `open -b <bundleId> <workspace>` (Cursor, VS Code 등)

## Release

DMG 생성에 `create-dmg` 사용:

```bash
brew install create-dmg
# build.sh 실행 후
create-dmg --volname "ClaudeNotify" --background <bg.png> --window-size 540 380 --icon-size 80 --icon "ClaudeNotify.app" 130 170 --icon ".claude" 410 170 ClaudeNotify.dmg <staging-dir>/
```
