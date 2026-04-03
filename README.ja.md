# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | **日本語** | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

Claude Code向けのmacOSネイティブ通知アプリです。タスクの完了や入力が必要な時に通知を受け取れます。

通知をクリックすると、Claude Codeが実行されている**正確なウィンドウとタブ**に移動します。

## 機能

- macOSネイティブ通知（`UNUserNotificationCenter`）
- ソースアプリのアイコン + プロジェクト名を通知に表示
- クリックで正確なウィンドウ/タブに移動：

| 環境 | 通知 | クリック移動 | 方式 |
|-------------|:----:|:----------:|--------|
| iTerm | O | ウィンドウ + タブ | Session GUID |
| Cursor | O | プロジェクトウィンドウ | Workspace path |
| VS Code | O | プロジェクトウィンドウ | Workspace path |
| macOS Terminal | O | ウィンドウ + タブ | TTY path |

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
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"入力待ち — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"タスク完了 — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ]
  }
}
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
    +-- ClaudeNotify.appを起動
          |
          +-- UNUserNotificationCenterで通知を送信
          +-- ソースアプリのアイコンを添付
          +-- セッション/workspace情報をuserInfoに保存
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

### VS Codeの通知がiTermタブに移動してしまう
- VS Codeターミナルに`ITERM_SESSION_ID`環境変数がリークしていることが原因です
- フックは`$__CFBundleIdentifier`を使用してアプリを区別するため、正常に動作するはずです

## アーキテクチャ

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist          # Bundle ID: com.claude.notify
    ├── MacOS/
    │   └── ClaudeNotify    # コンパイル済みバイナリ
    └── Resources/
        └── AppIcon.icns    # ベルアイコン

~/.claude/settings.json     # Claude Codeフック設定
```

**技術スタック：**
- Swift + Cocoa + UserNotifications + ApplicationServices
- UNUserNotificationCenter（モダンな通知API）
- Accessibility API（AXUIElement）でウィンドウ検出
- AppleScript（NSAppleScript）でiTerm/Terminalのタブ制御
- コード署名（hardened runtime + Apple Eventsエンタイトルメント）

## ライセンス

MIT
