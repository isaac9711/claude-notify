# ClaudeNotify

[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | **Español** | [Tiếng Việt](README.vi.md) | [Português](README.pt.md)

Una aplicacion nativa de notificaciones de macOS para Claude Code. Recibe notificaciones cuando las tareas se completan o se necesita entrada del usuario.

Haz clic en una notificacion para navegar a la **ventana y pestana exacta** donde se esta ejecutando Claude Code.

## Caracteristicas

- Notificaciones nativas de macOS (`UNUserNotificationCenter`)
- Icono de la aplicacion de origen + nombre del proyecto mostrados en la notificacion
- Navegacion al hacer clic a la ventana/pestana exacta:

| Entorno | Notificacion | Navegacion al hacer clic | Metodo |
|-------------|:----:|:----------:|--------|
| iTerm | O | Ventana + Pestana | Session GUID |
| Cursor | O | Ventana del proyecto | Ruta del workspace |
| VS Code | O | Ventana del proyecto | Ruta del workspace |
| macOS Terminal | O | Ventana + Pestana | Ruta TTY |

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

1. Descarga el nuevo DMG (o `git pull && ./build.sh`)
2. Arrastra `ClaudeNotify.app` a `Applications` y reemplaza la aplicación existente
3. Alterna ClaudeNotify **OFF → ON** en Ajustes del Sistema > Accesibilidad (el cambio del hash del binario invalida el permiso)

> La configuración de hooks en `~/.claude/settings.json` se conserva — no se necesitan cambios.

## Configuracion

### 1. Permisos de macOS

**Accesibilidad + Notificaciones (primer inicio):**
```bash
open /Applications/ClaudeNotify.app
```
- La configuracion de Accesibilidad se abrira automaticamente. Haz clic en `+` y agrega ClaudeNotify
- Ejecuta de nuevo para activar el dialogo de permisos de notificaciones. Permitelo

**Automatizacion de Terminal (si usas Terminal.app):**
```bash
open /Applications/ClaudeNotify.app --args --setup-terminal
```
Permite cuando aparezca el mensaje "ClaudeNotify wants to control Terminal".

### 2. Configuracion de Hooks de Claude Code

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
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Esperando entrada — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; fi; open /Applications/ClaudeNotify.app --args -title 'Claude Code' -message \"Tarea completada — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$PWD\" -session \"$S\""
          }
        ]
      }
    ]
  }
}
```

## Como funciona

### Flujo de notificaciones

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

### Flujo de navegacion al hacer clic

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

### La notificacion de VS Code navega a una pestana de iTerm
- Causado por la variable de entorno `ITERM_SESSION_ID` que se filtra al terminal de VS Code
- El hook usa `$__CFBundleIdentifier` para distinguir aplicaciones, por lo que deberia funcionar correctamente

## Arquitectura

```
/Applications/ClaudeNotify.app/
└── Contents/
    ├── Info.plist          # Bundle ID: com.claude.notify
    ├── MacOS/
    │   └── ClaudeNotify    # Binario compilado
    └── Resources/
        └── AppIcon.icns    # Icono de campana

~/.claude/settings.json     # Configuracion de hooks de Claude Code
```

**Stack tecnologico:**
- Swift + Cocoa + UserNotifications + ApplicationServices
- UNUserNotificationCenter (API moderna de notificaciones)
- Accessibility API (AXUIElement) para deteccion de ventanas
- AppleScript (NSAppleScript) para control de pestanas en iTerm/Terminal
- Firmado con hardened runtime + entitlement de Apple Events

## Licencia

MIT
