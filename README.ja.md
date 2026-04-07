# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | **日本語** | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

Claude Code向けのmacOSネイティブ通知アプリです。タスクの完了や入力が必要な時に通知を受け取れます。

通知をクリックすると、Claude Codeが実行されている**正確なウィンドウとタブ**に移動します。

## 機能

- **メニューバー常駐アプリ** — メニューバーにベルアイコンが表示、Dockアイコンなし
- **Sparkle自動アップデート** — GitHub Releasesを自動確認、ワンクリックでインストール
- **多言語対応** — 7言語（en、ko、zh、ja、es、vi、pt）、システム言語の自動検出と手動切り替えに対応
- **通知履歴** — 最新10件をメモリに保存、メニューバーから確認可能
- **IPC配信** — アプリ起動済みの場合、`DistributedNotificationCenter` 経由で新しい通知を配信（新プロセス起動なし）
- **ログイン時に起動** — デフォルトON、設定から切り替え可能
- macOSネイティブ通知（`UNUserNotificationCenter`）
- ソースアプリのアイコン + プロジェクト名を通知に表示
- クリックで正確なウィンドウ/タブに移動：

| 環境 | 通知 | クリック時の移動 | フルスクリーン Space | 方式 |
|------|:----:|:-----------:|:-----------:|------|
| iTerm | O | ウィンドウ + タブ | O | Session GUID + SkyLight API |
| Cursor | O | プロジェクトウィンドウ | O | Workspace path + SkyLight API |
| VS Code | O | プロジェクトウィンドウ | O | Workspace path + SkyLight API |
| macOS Terminal | O | ウィンドウ + タブ | O | TTY path + SkyLight API |
| Warp | O | アプリ起動 | X | open -b (Rustアプリの制限) |

## 動作環境

- macOS 14+（Sonoma以降）
- Swift 5.9+
- Claude Code CLI

## インストール

### 方法1: ビルド済みダウンロード（DMG）

1. [Releases](https://github.com/isaac9711/claude-notify/releases)からお使いのmacOSバージョン向けのDMGをダウンロード
2. DMGを開く
3. `ClaudeNotify.app`を`Applications`フォルダにドラッグ
4. 初回起動時にセキュリティ警告が表示された場合、**右クリック → 開く → 開く**（初回のみ）

> **ヒント:** または、ターミナルで`xattr -cr /Applications/ClaudeNotify.app`を実行するとセキュリティ警告をスキップできます。

### 方法2: ソースビルド

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### アップグレード

1. 新しい DMG をダウンロード（または `git pull && ./build.sh`）
2. `ClaudeNotify.app` を `Applications` に上書きコピー
3. システム設定 > アクセシビリティで ClaudeNotify を **OFF → ON** に切り替え（バイナリハッシュの変更により権限が無効化されます）

> `~/.claude/settings.json` の Hook 設定はそのまま保持されます。

## セットアップ

### 1. macOSの権限設定

**アクセシビリティ + 通知（初回起動時）：**
```bash
open /Applications/ClaudeNotify.app
```
- アクセシビリティ設定が自動的に開きます。`+`をクリックしてClaudeNotifyを追加してください
- もう一度実行して通知の許可ダイアログを表示させ、許可してください

**ターミナル自動化（Terminal.appを使用する場合）：**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
「ClaudeNotifyがTerminalを制御しようとしています」と表示されたら許可してください。

### 2. Claude Codeフック設定

`~/.claude/settings.json`の`hooks`セクションに追加：

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"入力待ち — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"タスク完了 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Git Worktree ワークスペースパス設定

デフォルトのHookは `git rev-parse --git-common-dir` を使用して、常に**ベースプロジェクトのルート**に解決します。これにより、Claude Codeがworktreeを作成した際に新しいウィンドウが開くのを防ぎます。

| シナリオ | デフォルト (git common dir) | 代替 (git show-toplevel) |
|----------|:---:|:---:|
| ベースプロジェクトウィンドウ | ベースウィンドウに移動 ✓ | ベースウィンドウに移動 ✓ |
| Worktreeウィンドウ（別途開いた場合） | ベースウィンドウに移動 | Worktreeウィンドウに移動 ✓ |
| Claude Codeが作成したworktree（ウィンドウなし） | ベースウィンドウに移動 ✓ | 新しいウィンドウを作成 |

主にworktreeを別のCursor/VS Codeウィンドウで開いて作業する場合は、Hookのworkspace部分を以下のように置き換えてください：

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
```

## 仕組み

### 通知フロー

```
Claude Codeフックが発火
    |
    +-- $__CFBundleIdentifierでアプリを識別（iTerm、Cursor、VS Code、Terminal）
    +-- セッション情報を取得:
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> psでttyパスを取得
    |     その他  -> （なし、workspaceパスを使用）
    |
    +-- ClaudeNotifyはすでに起動中?
          |
          +-- YES -> DistributedNotificationCenter経由でIPC配信
          |           アプリがペイロードを受信 → UNUserNotification送信 → 履歴更新
          |
          +-- NO  -> ClaudeNotify.appを起動（メニューバーに常駐）
                      |
                      +-- UNUserNotificationCenterで通知を送信
                      +-- ソースアプリのアイコンを添付
                      +-- セッション/workspace情報を通知履歴に保存
```

### クリック移動フロー

```
通知をクリック
    |
    +-- macOSがClaudeNotifyを再起動
    +-- didReceiveハンドラーが呼ばれる
    |
    +-- セッションタイプを判定:
          |
          +-- /dev/tty*  -> Terminal AppleScript（ttyマッチング）
          +-- w*t*p*:*   -> iTerm AppleScript（GUIDマッチング）
          +-- (その他)    -> open -b <bundleId> <workspace>
```

### ターミナルごとの移動方式

**iTerm:**
- `ITERM_SESSION_ID`からセッションGUIDを抽出
- AppleScriptで全ウィンドウ/タブ/セッションを走査し、一致するGUIDを検索
- 一致するウィンドウ + タブを選択

**macOS Terminal:**
- `ps -o tty= -p $PPID`で親プロセスのTTYパスを取得
- AppleScriptで全ウィンドウ/タブを走査し、TTYをマッチング
- 一致したタブを選択し、ウィンドウを前面に表示

**Cursor / VS Code:**
- `$PWD`（作業ディレクトリ）をworkspaceパスとして渡す
- `open -b <bundleId> <workspace>`でプロジェクトウィンドウをアクティブ化
- 各プロジェクトが独自のウィンドウを持つため、正確な移動が可能

## メニューバー

ClaudeNotifyはメニューバーにベルアイコン（`􀋚`）として常駐します。クリックすると以下にアクセスできます：

- **最近の通知** — タイトル・メッセージ・タイムスタンプ付きの最新10件。項目をクリックするとそのセッションに移動
- **アップデートを確認** — Sparkleで GitHub Releases を手動確認
- **設定**
  - ログイン時に起動（デフォルト：ON）
  - 自動アップデート（デフォルト：ON）
  - 言語 — システム自動検出または7言語から選択
- **終了**

## CLIオプション

```bash
# 通知を送信
open /Applications/ClaudeNotify.app --args \
  -title "Title" \
  -message "Body" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# フォーカスされたウィンドウのタイトルを取得（アクセシビリティ権限が必要）
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# Terminal自動化権限をリクエスト
open /Applications/ClaudeNotify.app --args --setup-terminal
```

### パラメータ

| パラメータ | 説明 | 例 |
|-----------|-------------|---------|
| `-title` | 通知タイトル | `Claude Code` |
| `-message` | 通知本文 | `Task complete — my-project` |
| `-sound` | 通知音 | `default` |
| `-activate` | クリック時にアクティブにするアプリのBundle ID | `com.googlecode.iterm2` |
| `-workspace` | プロジェクトパス（Cursor/VS Code用） | `/Users/me/project` |
| `-session` | セッション識別子（iTerm/Terminal用） | `w0t1p0:GUID` or `/dev/ttys001` |
| `-windowId` | フルスクリーン Space 切り替え用の CGWindowID:PID | `1181:31031` |

## トラブルシューティング

### 通知が表示されない
- システム設定 > 通知 > ClaudeNotifyが「バナー」または「通知」に設定されているか確認してください

### 通知クリック時に「開けません」エラー
- アプリを**右クリック → 開く**で一度開くか、`xattr -cr /Applications/ClaudeNotify.app`を実行してください
- `open /Applications/ClaudeNotify.app`を実行してアクセシビリティ設定を確認してください

### 再ビルド後に通知クリックが動作しなくなる
- 再ビルドによりバイナリハッシュが変更され、アクセシビリティ権限が無効化されます
- アクセシビリティ設定でClaudeNotifyを**OFF → ON**に切り替えてください

### Terminalタブ移動が動作しない
- システム設定 > 自動化 > ClaudeNotifyでTerminalが有効になっているか確認してください
- 有効でない場合：`open /Applications/ClaudeNotify.app --args --setup-terminal`

### Warp：フルスクリーン Space 切り替え非対応
- Warp は Rust ベースのアプリで、macOS SkyLight プライベート API に応答しません
- 通知クリックで Warp は起動しますが、フルスクリーン Space に切り替わりません
- 回避策：フルスクリーンの代わりにウィンドウモードまたは最大化（Option+緑ボタン）を使用

### VS Codeの通知がiTermタブに移動してしまう
- VS Codeターミナルに`ITERM_SESSION_ID`環境変数がリークしていることが原因です
- フックは`$__CFBundleIdentifier`を使用してアプリを区別するため、正常に動作するはずです

## アーキテクチャ

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist              # Bundle config + Sparkle keys
    ├── Frameworks/
    │   └── Sparkle.framework   # Auto-update framework
    ├── MacOS/
    │   └── ClaudeNotify        # Universal binary (arm64 + x86_64)
    └── Resources/
        └── AppIcon.icns        # Bell icon

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

**技術スタック：**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- Sparkle 2（GitHub Releases + EdDSA署名による自動アップデート）
- Swift Package Manager
- UNUserNotificationCenter（モダンな通知API）
- SMAppService（ログイン項目の管理）
- DistributedNotificationCenter（CLIと常駐アプリ間のIPC）
- メニューバー：NSStatusItem + SF Symbols（`bell.fill`）
- SkyLight private API（`_SLPSSetFrontProcessWithOptions`）でフルスクリーン Space 切り替え
- Accessibility API（AXUIElement）でウィンドウ検出
- AppleScript（NSAppleScript）でiTerm/Terminalのタブ制御
- コード署名（hardened runtime + Apple Eventsエンタイトルメント）

## ライセンス

MIT
