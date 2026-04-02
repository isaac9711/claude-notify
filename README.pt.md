# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | **Português**

Um aplicativo de notificações nativo para macOS voltado ao Claude Code. Receba notificações quando tarefas forem concluídas ou quando uma entrada for necessária.

Clique em uma notificação para navegar até a **janela e aba exatas** onde o Claude Code está sendo executado.

## Funcionalidades

- Notificações nativas do macOS (`UNUserNotificationCenter`)
- Ícone do aplicativo de origem + nome do projeto exibidos na notificação
- Navegação por clique até a janela/aba exata:

| Ambiente | Notificação | Navegação por Clique | Método |
|-------------|:----:|:----------:|--------|
| iTerm | O | Janela + Aba | Session GUID |
| Cursor | O | Janela do Projeto | Workspace path |
| VS Code | O | Janela do Projeto | Workspace path |
| macOS Terminal | O | Janela + Aba | TTY path |

## Requisitos

- macOS 14+ (Sonoma ou posterior)
- Swift 5.9+
- Claude Code CLI

## Instalação

### Opção 1: Compilação a partir do código-fonte (recomendado)

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Opção 2: Download pré-compilado (DMG)

1. Baixe o DMG correspondente à sua versão do macOS em [Releases](https://github.com/isaac9711/claude-notify/releases)
2. Abra o DMG
3. Arraste `ClaudeNotify.app` para a pasta `Applications`
4. Na primeira execução, se um aviso de segurança aparecer, **Clique com o botão direito → Abrir → Abrir** (apenas uma vez)

> **Dica:** Alternativamente, execute `xattr -cr /Applications/ClaudeNotify.app` no Terminal para ignorar o aviso de segurança.

## Configuração

### 1. Permissões do macOS

**Acessibilidade + Notificações (primeira execução):**
```bash
open /Applications/ClaudeNotify.app
```
- As configurações de Acessibilidade serão abertas automaticamente. Clique em `+` e adicione o ClaudeNotify
- Execute novamente para acionar o diálogo de permissão de notificações. Permita

**Automação do Terminal (se estiver usando o Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Permita quando o sistema solicitar "ClaudeNotify wants to control Terminal".

### 2. Configuração de Hook do Claude Code

Adicione à seção `hooks` do `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Aguardando entrada — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Tarefa concluída — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ]
  }
}
```

## Como Funciona

### Fluxo de Notificação

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

### Fluxo de Navegação por Clique

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

### Navegação por Terminal

**iTerm:**
- Extrai o GUID da sessão a partir de `ITERM_SESSION_ID`
- AppleScript itera por todas as janelas/abas/sessões para encontrar o GUID correspondente
- Seleciona a janela + aba correspondente

**macOS Terminal:**
- Obtém o caminho TTY do processo pai via `ps -o tty= -p $PPID`
- AppleScript itera por todas as janelas/abas para encontrar o TTY correspondente
- Define a aba correspondente como selecionada e traz a janela para o primeiro plano

**Cursor / VS Code:**
- Passa `$PWD` (diretório de trabalho) como caminho do workspace
- `open -b <bundleId> <workspace>` ativa a janela do projeto
- Cada projeto possui sua própria janela, garantindo navegação precisa

## Opções de CLI

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

### Parametros

| Parametro | Descricao | Exemplo |
|-----------|-----------|---------|
| `-title` | Titulo da notificacao | `Claude Code` |
| `-message` | Corpo da notificacao | `Task complete — my-project` |
| `-sound` | Som da notificacao | `default` |
| `-activate` | Bundle ID do aplicativo a ser ativado ao clicar | `com.googlecode.iterm2` |
| `-workspace` | Caminho do projeto (para Cursor/VS Code) | `/Users/me/project` |
| `-session` | Identificador de sessao (para iTerm/Terminal) | `w0t1p0:GUID` ou `/dev/ttys001` |

## Solucao de Problemas

### Notificacoes nao aparecem
- Verifique em Ajustes do Sistema > Notificacoes > ClaudeNotify se esta definido como "Banners" ou "Alertas"

### Erro "Cannot be opened" ao clicar na notificacao
- **Clique com o botao direito → Abrir** o aplicativo uma vez, ou execute `xattr -cr /Applications/ClaudeNotify.app`
- Execute `open /Applications/ClaudeNotify.app` para verificar as configuracoes de Acessibilidade

### Clique na notificacao para de funcionar apos recompilacao
- A recompilacao altera o hash do binario, invalidando a permissao de Acessibilidade
- Alterne ClaudeNotify **OFF → ON** nas configuracoes de Acessibilidade

### Navegacao por aba do Terminal nao funciona
- Verifique em Ajustes do Sistema > Automacao > ClaudeNotify se o Terminal esta habilitado
- Se nao estiver: `open /Applications/ClaudeNotify.app --args --setup-terminal`

### Notificacao do VS Code navega para aba do iTerm
- Causado pela variavel de ambiente `ITERM_SESSION_ID` vazando para o terminal do VS Code
- O hook usa `$__CFBundleIdentifier` para distinguir aplicativos, entao isso deve funcionar corretamente

## Arquitetura

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

**Stack Tecnologica:**
- Swift + Cocoa + UserNotifications + ApplicationServices
- UNUserNotificationCenter (API moderna de notificacoes)
- Accessibility API (AXUIElement) para deteccao de janelas
- AppleScript (NSAppleScript) para controle de abas do iTerm/Terminal
- Assinatura de codigo com hardened runtime + entitlement de Apple Events

## Licenca

MIT
