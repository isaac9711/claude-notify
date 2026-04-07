# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Tiếng Việt](README.vi.md) | **Português**

Um aplicativo de notificações nativo para macOS voltado ao Claude Code. Receba notificações quando tarefas forem concluídas ou quando uma entrada for necessária.

Clique em uma notificação para navegar até a **janela e aba exatas** onde o Claude Code está sendo executado.

## Funcionalidades

- **Aplicativo residente na barra de menus** — ícone de sino na barra de menus, sem ícone no Dock
- **Atualização automática com Sparkle** — verifica GitHub Releases automaticamente, instala com um clique
- **Suporte a múltiplos idiomas** — 7 idiomas (en, ko, zh, ja, es, vi, pt) com detecção automática do sistema e troca manual
- **Histórico de notificações** — as últimas 10 notificações são salvas em memória, acessíveis pela barra de menus
- **Entrega via IPC** — quando o aplicativo já está em execução, novas notificações são entregues via `DistributedNotificationCenter` sem lançar um novo processo
- **Iniciar no login** — ativado por padrão, configurável em Ajustes
- Notificações nativas do macOS (`UNUserNotificationCenter`)
- Ícone do aplicativo de origem + nome do projeto exibidos na notificação
- Navegação por clique até a janela/aba exata:

| Ambiente | Notificação | Navegação ao clicar | Fullscreen Space | Método |
|----------|:----:|:----------:|:----------:|--------|
| iTerm | O | Janela + Aba | O | Session GUID + SkyLight API |
| Cursor | O | Janela do projeto | O | Workspace path + SkyLight API |
| VS Code | O | Janela do projeto | O | Workspace path + SkyLight API |
| macOS Terminal | O | Janela + Aba | O | TTY path + SkyLight API |
| Warp | O | Ativar aplicativo | X | open -b (limitação de app Rust) |

## Requisitos

- macOS 14+ (Sonoma ou posterior)
- Swift 5.9+
- Claude Code CLI

## Instalação

### Opção 1: Download pré-compilado (DMG)

1. Baixe o DMG correspondente à sua versão do macOS em [Releases](https://github.com/isaac9711/claude-notify/releases)
2. Abra o DMG
3. Arraste `ClaudeNotify.app` para a pasta `Applications`
4. Na primeira execução, se um aviso de segurança aparecer, **Clique com o botão direito → Abrir → Abrir** (apenas uma vez)

> **Dica:** Alternativamente, execute `xattr -cr /Applications/ClaudeNotify.app` no Terminal para ignorar o aviso de segurança.

### Opção 2: Compilação a partir do código-fonte

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Atualização

1. Baixe o novo DMG (ou `git pull && ./build.sh`)
2. Arraste `ClaudeNotify.app` para `Applications` e substitua o aplicativo existente
3. Alterne ClaudeNotify **OFF → ON** em Ajustes do Sistema > Acessibilidade (a mudança do hash do binário invalida a permissão)

> A configuração de hooks em `~/.claude/settings.json` é preservada — nenhuma alteração necessária.

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
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Aguardando entrada — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Tarefa concluída — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Configuração de caminho do workspace para Git Worktrees

O hook padrão usa `git rev-parse --git-common-dir` para sempre resolver para o **diretório raiz do projeto base**. Isso evita que novas janelas sejam abertas quando o Claude Code cria worktrees.

| Cenário | Padrão (git common dir) | Alternativa (git show-toplevel) |
|----------|:---:|:---:|
| Janela do projeto base | Vai para a janela base ✓ | Vai para a janela base ✓ |
| Janela de worktree (aberta separadamente) | Vai para a janela base | Vai para a janela do worktree ✓ |
| Worktree criado pelo Claude Code (sem janela) | Vai para a janela base ✓ | Cria nova janela |

Se você trabalha principalmente com worktrees abertos como janelas separadas do Cursor/VS Code, substitua a parte do workspace nos seus hooks:

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
```

## Como Funciona

### Fluxo de Notificação

```
Claude Code hook é acionado
    |
    +-- Identificar app via $__CFBundleIdentifier (iTerm, Cursor, VS Code, Terminal)
    +-- Capturar info de sessão:
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> caminho tty via ps
    |     Outros  -> (nenhum, usa caminho do workspace)
    |
    +-- ClaudeNotify já está em execução?
          |
          +-- SIM -> entregar via DistributedNotificationCenter (IPC)
          |           app recebe payload → envia UNUserNotification → atualiza histórico
          |
          +-- NÃO -> lançar ClaudeNotify.app (fica residente na barra de menus)
                      |
                      +-- Enviar notificação via UNUserNotificationCenter
                      +-- Anexar ícone do app de origem
                      +-- Salvar info de sessão/workspace no histórico de notificações
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

## Barra de Menus

O ClaudeNotify fica residente na barra de menus como um ícone de sino (`􀋚`). Clique nele para acessar:

- **Notificações Recentes** — as últimas 10 notificações com título, mensagem e hora; clique em uma entrada para navegar até aquela sessão
- **Verificar Atualizações** — acionar manualmente uma verificação de atualização Sparkle no GitHub Releases
- **Ajustes**
  - Iniciar no Login (padrão: ATIVADO)
  - Atualizações Automáticas (padrão: ATIVADO)
  - Idioma — escolha detecção automática do sistema ou um dos 7 idiomas
- **Sair**

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
| `-windowId` | CGWindowID:PID para troca de Space em tela cheia | `1181:31031` |

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

### Warp: troca de Space em tela cheia não suportada
- Warp é um aplicativo baseado em Rust que não responde à API privada SkyLight do macOS
- Clicar na notificação ativará o Warp, mas não poderá alternar para o Space em tela cheia
- Solução: use modo janela ou maximize (Option+botão verde) em vez de tela cheia

### Notificacao do VS Code navega para aba do iTerm
- Causado pela variavel de ambiente `ITERM_SESSION_ID` vazando para o terminal do VS Code
- O hook usa `$__CFBundleIdentifier` para distinguir aplicativos, entao isso deve funcionar corretamente

## Arquitetura

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist              # Bundle config + Sparkle keys
    ├── Frameworks/
    │   └── Sparkle.framework   # Auto-update framework
    ├── MacOS/
    │   └── ClaudeNotify        # Universal binary (arm64 + x86_64)
    └── Resources/
        └── AppIcon.icns        # Ícone de sino

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

**Stack Tecnológica:**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- Sparkle 2 (atualização automática via GitHub Releases + assinatura EdDSA)
- Swift Package Manager
- UNUserNotificationCenter (API moderna de notificações)
- SMAppService (gerenciamento de item de login)
- DistributedNotificationCenter (IPC entre CLI e o app residente)
- Barra de menus: NSStatusItem + SF Symbols (`bell.fill`)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) para troca de Space em tela cheia
- Accessibility API (AXUIElement) para detecção de janelas
- AppleScript (NSAppleScript) para controle de abas do iTerm/Terminal
- Assinatura de código com hardened runtime + entitlement de Apple Events

## Licenca

MIT
