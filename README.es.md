# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | **Español** | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

Una aplicacion nativa de notificaciones de macOS para Claude Code. Recibe notificaciones cuando las tareas se completan o se necesita entrada del usuario.

Haz clic en una notificacion para navegar a la **ventana y pestana exacta** donde se esta ejecutando Claude Code.

## Caracteristicas

- **Aplicación residente en la barra de menú** — icono de campana en la barra de menú, sin icono en el Dock
- **Actualización automática con Sparkle** — comprueba GitHub Releases automáticamente, se instala con un clic
- **Soporte multiidioma** — 7 idiomas (en, ko, zh, ja, es, vi, pt) con detección automática del sistema e cambio manual
- **Historial de notificaciones** — las últimas 10 notificaciones se guardan en memoria, consultables desde la barra de menú
- **Entrega por IPC** — cuando la app ya está en ejecución, las nuevas notificaciones se entregan via `DistributedNotificationCenter` sin lanzar un nuevo proceso
- **Iniciar al iniciar sesión** — activado por defecto, configurable en Ajustes
- **Configuración automática de hooks** — asistente en el primer inicio que instala los hooks con vista previa de diferencias; detecta y solicita actualizaciones tras las actualizaciones de la app
- Notificaciones nativas de macOS (`UNUserNotificationCenter`)
- Icono de la aplicacion de origen + nombre del proyecto mostrados en la notificacion
- Navegacion al hacer clic a la ventana/pestana exacta:

| Entorno | Notificación | Navegación al clic | Pantalla completa Space | Método |
|---------|:----:|:----------:|:----------:|--------|
| iTerm | O | Ventana + Pestaña | O | Session GUID + SkyLight API |
| Cursor | O | Ventana del proyecto | O | Workspace path + SkyLight API |
| VS Code | O | Ventana del proyecto | O | Workspace path + SkyLight API |
| macOS Terminal | O | Ventana + Pestaña | O | TTY path + SkyLight API |
| Warp | O | Activar aplicación | X | open -b (limitación de app Rust) |

## Requisitos

- macOS 14+ (Sonoma o posterior)
- Swift 5.9+
- Claude Code CLI

## Instalacion

### Opcion 1: Descarga precompilada (DMG)

1. Descarga el DMG para tu version de macOS desde [Releases](https://github.com/isaac9711/claude-notify/releases)
2. Abre el DMG
3. Arrastra `ClaudeNotify.app` a la carpeta `Applications`
4. En el primer inicio, si aparece una advertencia de seguridad, **Clic derecho → Abrir → Abrir** (solo una vez)

> **Consejo:** Alternativamente, ejecuta `xattr -cr /Applications/ClaudeNotify.app` en Terminal para omitir la advertencia de seguridad.

### Opcion 2: Compilar desde el codigo fuente

```bash
git clone https://github.com/isaac9711/claude-notify.git
cd claude-notify
./build.sh
```

### Actualización

La aplicación admite **actualización automática con Sparkle** — haz clic en "Buscar actualizaciones" en la barra de menú para actualizar. Para compilaciones desde el código fuente, ejecuta `git pull && ./build.sh`.

Tras cualquier actualización, alterna ClaudeNotify **OFF → ON** en Ajustes del Sistema > Accesibilidad (el cambio del hash del binario invalida el permiso).

> La configuración de hooks en `~/.claude/settings.json` se conserva — no se necesitan cambios.

## Configuracion

### 1. Permisos de macOS

**Iniciar la aplicación (primer inicio):**

Simplemente abre ClaudeNotify.app — haz doble clic en Finder o ábrelo desde Spotlight. La aplicación permanece residente en la barra de menú y se inicia al iniciar sesión por defecto. El primer inicio activa automáticamente las solicitudes de permiso de Accesibilidad y Notificaciones.

**Automatizacion de Terminal (si usas Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Permite cuando aparezca el mensaje "ClaudeNotify wants to control Terminal".

### 2. Configuracion de Hooks de Claude Code

#### Configuración automática (recomendado)

En el primer inicio, ClaudeNotify te guía para seleccionar tu archivo `settings.json` e instala los hooks automáticamente. Se muestra una vista previa de diferencias con los cambios exactos antes de aplicarlos. También puedes instalar o desinstalar hooks más adelante desde la barra de menú: **Ajustes > Hook > Instalar/Desinstalar Hooks, Cambiar archivo de configuración**.

#### Configuración manual

Agrega a la seccion `hooks` de `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Esperando entrada — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Tarea completada — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""
          }
        ]
      }
    ]
  }
}
```

### Configuración de ruta de workspace para Git Worktrees

El hook predeterminado usa `git rev-parse --git-common-dir` para resolver siempre al **directorio raíz del proyecto base**. Esto evita que se abran nuevas ventanas cuando Claude Code crea worktrees.

| Escenario | Predeterminado (git common dir) | Alternativa (git show-toplevel) |
|----------|:---:|:---:|
| Ventana del proyecto base | Va a la ventana base ✓ | Va a la ventana base ✓ |
| Ventana de worktree (abierta por separado) | Va a la ventana base | Va a la ventana del worktree ✓ |
| Worktree creado por Claude Code (sin ventana) | Va a la ventana base ✓ | Crea nueva ventana |

Si trabajas principalmente con worktrees abiertos como ventanas separadas de Cursor/VS Code, reemplaza la parte del workspace en tus hooks:

```diff
- -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\"
+ -workspace \"$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)\"
```

## Como funciona

### Flujo de notificaciones

```
Claude Code hook se ejecuta
    |
    +-- Identificar app via $__CFBundleIdentifier (iTerm, Cursor, VS Code, Terminal)
    +-- Capturar info de sesión:
    |     iTerm   -> $ITERM_SESSION_ID (GUID)
    |     Terminal -> ruta tty via ps
    |     Otros   -> (ninguna, usa ruta del workspace)
    |
    +-- ¿ClaudeNotify ya está en ejecución?
          |
          +-- SÍ -> entregar via DistributedNotificationCenter (IPC)
          |          la app recibe el payload → envía UNUserNotification → actualiza historial
          |
          +-- NO -> lanzar ClaudeNotify.app (se queda residente en la barra de menú)
                     |
                     +-- Enviar notificación via UNUserNotificationCenter
                     +-- Adjuntar icono de la app de origen
                     +-- Guardar info de sesión/workspace en el historial
```

### Flujo de navegacion al hacer clic

```
Se hace clic en la notificación
    |
    +-- La app ya está en ejecución (residente en la barra de menú)
    +-- El handler didReceive es llamado directamente
    |
    +-- Determinar tipo de sesión:
          |
          +-- /dev/tty*  -> Terminal AppleScript (coincidencia tty)
          +-- w*t*p*:*   -> iTerm AppleScript (coincidencia GUID)
          +-- activate-only -> Warp (solo activar la app)
          +-- (otro)     -> open -b <bundleId> <workspace>
```

### Navegacion por terminal

**iTerm:**
- Extrae el GUID de sesion de `ITERM_SESSION_ID`
- AppleScript itera todas las ventanas/pestanas/sesiones para encontrar el GUID coincidente
- Selecciona la ventana + pestana coincidente

**macOS Terminal:**
- Obtiene la ruta TTY del proceso padre mediante `ps -o tty= -p $PPID`
- AppleScript itera todas las ventanas/pestanas para encontrar la TTY coincidente
- Establece la pestana coincidente como seleccionada y trae la ventana al frente

**Cursor / VS Code:**
- Pasa `$PWD` (directorio de trabajo) como ruta del workspace
- `open -b <bundleId> <workspace>` activa la ventana del proyecto
- Cada proyecto tiene su propia ventana, asegurando una navegacion precisa

## Barra de menú

ClaudeNotify reside en la barra de menú como un icono de campana (`􀋚`). Al hacer clic tienes acceso a:

- **Notificaciones recientes** — las últimas 10 notificaciones con título, mensaje y hora; haz clic en una entrada para navegar a esa sesión
- **Buscar actualizaciones** — desencadenar manualmente una comprobación de actualizaciones Sparkle en GitHub Releases
- **Ajustes**
  - Iniciar al iniciar sesión (por defecto: ON)
  - Actualizaciones automáticas (por defecto: ON)
  - Idioma — elige detección automática del sistema o uno de los 7 idiomas
  - Hook > Instalar/Desinstalar Hooks, Cambiar archivo de configuración
- **Salir**

## Opciones de CLI

```bash
# Enviar notificacion
open /Applications/ClaudeNotify.app --args \
  -title "Title" \
  -message "Body" \
  -sound default \
  -activate <bundleId> \
  -workspace <path> \
  -session <sessionId>

# Obtener titulo de la ventana enfocada (requiere Accesibilidad)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-title <bundleId>

# Obtener ID de la ventana enfocada (requiere Accesibilidad)
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
  --get-window-id <bundleId>

# Comprobar/solicitar permiso de Accesibilidad
/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify --setup

# Solicitar permiso de automatizacion de Terminal
open /Applications/ClaudeNotify.app --args --setup-terminal
```

### Parametros

| Parametro | Descripcion | Ejemplo |
|-----------|-------------|---------|
| `-title` | Titulo de la notificacion | `Claude Code` |
| `-message` | Cuerpo de la notificacion | `Task complete — my-project` |
| `-sound` | Sonido de la notificacion | `default` |
| `-activate` | Bundle ID de la aplicacion a activar al hacer clic | `com.googlecode.iterm2` |
| `-workspace` | Ruta del proyecto (para Cursor/VS Code) | `/Users/me/project` |
| `-session` | Identificador de sesion (para iTerm/Terminal) | `w0t1p0:GUID` o `/dev/ttys001` |
| `-windowId` | CGWindowID:PID para cambio de Space en pantalla completa | `1181:31031` |

## Solucion de problemas

### Las notificaciones no aparecen
- Verifica en Ajustes del Sistema > Notificaciones > ClaudeNotify que este configurado como "Banners" o "Alerts"

### Error "Cannot be opened" al hacer clic en la notificacion
- **Clic derecho → Abrir** la aplicacion una vez, o ejecuta `xattr -cr /Applications/ClaudeNotify.app`
- Ejecuta `open /Applications/ClaudeNotify.app` para verificar la configuracion de Accesibilidad

### La navegacion al hacer clic deja de funcionar despues de recompilar
- Recompilar cambia el hash del binario, invalidando el permiso de Accesibilidad
- Desactiva y reactiva ClaudeNotify (**OFF → ON**) en la configuracion de Accesibilidad

### La navegacion de pestanas de Terminal no funciona
- Verifica en Ajustes del Sistema > Automatizacion > ClaudeNotify que Terminal este habilitado
- Si no lo esta: `open /Applications/ClaudeNotify.app --args --setup-terminal`

### Warp: cambio de Space en pantalla completa no soportado
- Warp es una aplicación basada en Rust que no responde a la API privada SkyLight de macOS
- Al hacer clic en la notificación se activará Warp pero no podrá cambiar al Space en pantalla completa
- Solución: usa modo ventana o maximiza (Option+botón verde) en lugar de pantalla completa

### La notificacion de VS Code navega a una pestana de iTerm
- Causado por la variable de entorno `ITERM_SESSION_ID` que se filtra al terminal de VS Code
- El hook usa `$__CFBundleIdentifier` para distinguir aplicaciones, por lo que deberia funcionar correctamente

## Arquitectura

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist              # Bundle config + Sparkle keys
    ├── Frameworks/
    │   └── Sparkle.framework   # Auto-update framework
    ├── MacOS/
    │   └── ClaudeNotify        # Universal binary (arm64 + x86_64)
    └── Resources/
        ├── AppIcon.icns        # Icono de campana
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

**Stack tecnologico:**
- Swift + Cocoa + UserNotifications + ApplicationServices + SkyLight
- Sparkle 2 (actualización automática via GitHub Releases + firma EdDSA)
- Swift Package Manager
- UNUserNotificationCenter (API moderna de notificaciones)
- SMAppService (gestión del elemento de inicio de sesión)
- DistributedNotificationCenter (IPC entre CLI y la app residente)
- Barra de menú: NSStatusItem + SF Symbols (`bell.fill`)
- SkyLight private API (`_SLPSSetFrontProcessWithOptions`) para cambio de Space en pantalla completa
- Accessibility API (AXUIElement) para deteccion de ventanas
- AppleScript (NSAppleScript) para control de pestanas en iTerm/Terminal
- Firmado con hardened runtime + entitlement de Apple Events

## Licencia

MIT
