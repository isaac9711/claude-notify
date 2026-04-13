# ClaudeNotify

macOS용 Claude Code 알림 앱. 메뉴바 상주 + Sparkle 자동 업데이트 + 다국어 지원.

Swift + Cocoa + SPM + Sparkle 2 + UNUserNotificationCenter 기반.

## Build

```bash
./build.sh
```

빌드 결과물: `/Applications/ClaudeNotify.app`

재빌드 후 반드시 시스템 설정 > 손쉬운 사용에서 ClaudeNotify를 OFF → ON 토글해야 함 (바이너리 해시 변경으로 인한 권한 무효화).

## Architecture

SPM 기반 멀티파일 프로젝트:

```
Package.swift                    — SPM 패키지 정의 (Sparkle 의존성)
Sources/ClaudeNotify/
  main.swift                     — 진입점, CLI 모드 분기, IPC 발신
  AppDelegate.swift              — 메뉴바 UI, 알림 처리, Sparkle, 로그인 관리
  WindowActivation.swift         — SkyLight 비공개 API, 창 활성화/조회
  NotificationPayload.swift      — 페이로드 구조체, 인자 파싱, JSON 직렬화
  NotificationHistory.swift      — 인메모리 알림 기록 (최대 10개)
  Localization.swift             — 딕셔너리 기반 다국어 (7개 언어)
Resources/
  Info.plist                     — 앱 번들 설정 (Bundle ID: com.claude.notify, Sparkle 키)
  AppIcon.icns                   — 벨 아이콘
  ClaudeNotify.entitlements      — hardened runtime + Apple Events + disable-library-validation
build.sh                         — SPM 빌드 + universal binary + Sparkle.framework 복사 + 코드서명
appcast.xml                      — Sparkle 업데이트 피드
```

## 앱 모드

### 상주 모드 (기본)

메뉴바에 bell.fill 아이콘으로 상주. 인자 없이 실행하거나 알림 인자로 실행.

- **IPC**: 앱이 이미 실행 중이면 `DistributedNotificationCenter`로 알림 전달 후 두 번째 인스턴스 종료
- **메뉴**: 최근 알림 (10개) / 업데이트 확인 / 설정 (로그인 시 자동 시작, 자동 업데이트, 언어) / 종료
- **자동 업데이트**: Sparkle 2 + GitHub Releases + EdDSA 서명
- **로그인 시 자동 시작**: SMAppService (기본 ON, 설정에서 토글)
- **다국어**: en, ko, zh, ja, es, vi, pt (시스템 언어 자동 감지 + 설정 오버라이드)

### CLI 모드 (즉시 실행 후 종료)

1. **알림 전송**: `open ClaudeNotify.app --args -title ... -message ... -activate ... -workspace ... -session ...`
2. **창 제목 조회**: `ClaudeNotify --get-window-title <bundleId>` — AX API로 포커스된 창 제목 반환
3. **창 ID 조회**: `ClaudeNotify --get-window-id <bundleId>` — CGWindowID:PID 반환
4. **Terminal 권한 요청**: `open ClaudeNotify.app --args --setup-terminal` — Terminal 자동화 권한 팝업 트리거
5. **Terminal 탭 전환**: `ClaudeNotify --raise-terminal <tty>` — 내부용, 알림 클릭 시 호출
6. **접근성 권한 확인**: `ClaudeNotify --setup`

## Click Navigation Logic

`didReceive` 핸들러에서 session 파라미터로 분기 (상주 앱이므로 처리 후 종료하지 않음):

- `/dev/tty*` → macOS Terminal: `osascript`로 tty 매칭하여 탭 선택
- `w*t*p*:GUID` → iTerm: `NSAppleScript`로 GUID 매칭하여 세션 선택
- `activate-only` → Warp: 앱 활성화만
- 그 외 → `open -b <bundleId> <workspace>` (Cursor, VS Code 등)

## Versioning

빌드 번호 분리 체계:

- `CFBundleShortVersionString` — 마케팅 버전 (예: `1.1`). 큰 기능 추가 시만 변경.
- `CFBundleVersion` — 빌드 번호 (예: `20260413`). `build.sh` 실행 시 날짜 기반 자동 생성.
- `Info.plist`에 `BUILD_NUMBER` 플레이스홀더, `build.sh`가 `sed`로 치환.
- Sparkle은 `CFBundleVersion` (빌드 번호)으로 업데이트 비교, 사용자에게는 마케팅 버전만 표시.
- 빌드 번호 고정: `CLAUDE_NOTIFY_BUILD_NUMBER=20260413 ./build.sh`

## Release

`release.sh`로 전체 릴리즈 파이프라인 자동화:

```bash
# 버그 수정 릴리즈 (마케팅 버전 유지)
./release.sh

# 새 기능 릴리즈 (마케팅 버전 변경)
./release.sh --version 1.2

# 특정 태그명 지정
./release.sh --version 1.2 --tag v1.2.0
```

`release.sh`가 수행하는 작업:
1. 빌드 번호 생성 (YYYYMMDD)
2. `build.sh` 실행 (빌드 번호 고정)
3. 빌드 검증 (버전 불일치 방지)
4. zip 생성 + EdDSA 서명 (`sign_update`)
5. `appcast.xml` 업데이트 (버전, 서명, URL)
6. git 커밋 + push
7. GitHub Release 생성 + zip 업로드

수동 DMG 생성 (선택, 추가 배포 채널용):

```bash
brew install create-dmg
create-dmg --volname "ClaudeNotify" --window-size 540 380 --icon-size 80 --icon "ClaudeNotify.app" 130 170 --app-drop-link 410 170 ClaudeNotify.dmg <staging-dir>/
```
