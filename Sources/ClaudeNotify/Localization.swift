import Foundation

enum Language: String, CaseIterable {
    case system = "system"
    case en = "en"
    case ko = "ko"
    case zh = "zh"
    case ja = "ja"
    case es = "es"
    case vi = "vi"
    case pt = "pt"

    var displayName: String {
        switch self {
        case .system: return "System (\(Language.resolvedSystemLanguage.displayName))"
        case .en: return "English"
        case .ko: return "한국어"
        case .zh: return "中文"
        case .ja: return "日本語"
        case .es: return "Español"
        case .vi: return "Tiếng Việt"
        case .pt: return "Português"
        }
    }

    static var resolvedSystemLanguage: Language {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = String(preferred.prefix(2))
        return Language(rawValue: code) ?? .en
    }

    static var current: Language {
        let saved = UserDefaults.standard.string(forKey: "language") ?? "system"
        let lang = Language(rawValue: saved) ?? .system
        if lang == .system { return resolvedSystemLanguage }
        return lang
    }

    static var savedSelection: Language {
        let saved = UserDefaults.standard.string(forKey: "language") ?? "system"
        return Language(rawValue: saved) ?? .system
    }
}

enum L10n {
    private static let strings: [String: [String: String]] = [
        "recentNotifications": [
            "en": "Recent Notifications",
            "ko": "최근 알림",
            "zh": "最近通知",
            "ja": "最近の通知",
            "es": "Notificaciones recientes",
            "vi": "Thông báo gần đây",
            "pt": "Notificações recentes",
        ],
        "noNotifications": [
            "en": "No Notifications",
            "ko": "알림 없음",
            "zh": "没有通知",
            "ja": "通知なし",
            "es": "Sin notificaciones",
            "vi": "Không có thông báo",
            "pt": "Sem notificações",
        ],
        "clearHistory": [
            "en": "Clear History",
            "ko": "기록 지우기",
            "zh": "清除记录",
            "ja": "履歴を消去",
            "es": "Borrar historial",
            "vi": "Xóa lịch sử",
            "pt": "Limpar histórico",
        ],
        "checkForUpdates": [
            "en": "Check for Updates...",
            "ko": "업데이트 확인...",
            "zh": "检查更新...",
            "ja": "アップデートを確認...",
            "es": "Buscar actualizaciones...",
            "vi": "Kiểm tra cập nhật...",
            "pt": "Verificar atualizações...",
        ],
        "settings": [
            "en": "Settings",
            "ko": "설정",
            "zh": "设置",
            "ja": "設定",
            "es": "Configuración",
            "vi": "Cài đặt",
            "pt": "Configurações",
        ],
        "launchAtLogin": [
            "en": "Launch at Login",
            "ko": "로그인 시 자동 시작",
            "zh": "登录时自动启动",
            "ja": "ログイン時に起動",
            "es": "Iniciar al iniciar sesión",
            "vi": "Khởi động khi đăng nhập",
            "pt": "Iniciar no login",
        ],
        "automaticUpdates": [
            "en": "Automatic Updates",
            "ko": "자동 업데이트",
            "zh": "自动更新",
            "ja": "自動アップデート",
            "es": "Actualizaciones automáticas",
            "vi": "Cập nhật tự động",
            "pt": "Atualizações automáticas",
        ],
        "language": [
            "en": "Language",
            "ko": "언어",
            "zh": "语言",
            "ja": "言語",
            "es": "Idioma",
            "vi": "Ngôn ngữ",
            "pt": "Idioma",
        ],
        "noUpdatesTitle": [
            "en": "No Updates Available",
            "ko": "최신 버전입니다",
            "zh": "没有可用更新",
            "ja": "アップデートはありません",
            "es": "No hay actualizaciones",
            "vi": "Không có bản cập nhật",
            "pt": "Nenhuma atualização disponível",
        ],
        "noUpdatesMessage": [
            "en": "ClaudeNotify v{version} is currently the latest version.",
            "ko": "ClaudeNotify v{version}은(는) 현재 최신 버전입니다.",
            "zh": "ClaudeNotify v{version} 已是最新版本。",
            "ja": "ClaudeNotify v{version} は最新バージョンです。",
            "es": "ClaudeNotify v{version} es la versión más reciente.",
            "vi": "ClaudeNotify v{version} là phiên bản mới nhất.",
            "pt": "ClaudeNotify v{version} é a versão mais recente.",
        ],
        "hooks": [
            "en": "Hooks",
            "ko": "Hook",
            "zh": "Hook",
            "ja": "Hook",
            "es": "Hooks",
            "vi": "Hook",
            "pt": "Hooks",
        ],
        "installHooks": [
            "en": "Install Hooks",
            "ko": "Hook 설치",
            "zh": "安装 Hook",
            "ja": "Hook をインストール",
            "es": "Instalar Hooks",
            "vi": "Cài đặt Hook",
            "pt": "Instalar Hooks",
        ],
        "uninstallHooks": [
            "en": "Uninstall Hooks",
            "ko": "Hook 제거",
            "zh": "卸载 Hook",
            "ja": "Hook をアンインストール",
            "es": "Desinstalar Hooks",
            "vi": "Gỡ cài đặt Hook",
            "pt": "Desinstalar Hooks",
        ],
        "changeSettingsPath": [
            "en": "Change Settings File...",
            "ko": "설정 파일 변경...",
            "zh": "更改设置文件...",
            "ja": "設定ファイルを変更...",
            "es": "Cambiar archivo de configuración...",
            "vi": "Thay đổi tệp cài đặt...",
            "pt": "Alterar arquivo de configuração...",
        ],
        "selectSettingsFile": [
            "en": "Select Claude Code settings.json",
            "ko": "Claude Code settings.json 파일을 선택하세요",
            "zh": "选择 Claude Code settings.json",
            "ja": "Claude Code の settings.json を選択してください",
            "es": "Seleccione settings.json de Claude Code",
            "vi": "Chọn tệp settings.json của Claude Code",
            "pt": "Selecione o settings.json do Claude Code",
        ],
        "hooksInstalled": [
            "en": "Hooks installed successfully.",
            "ko": "Hook이 설치되었습니다.",
            "zh": "Hook 安装成功。",
            "ja": "Hook をインストールしました。",
            "es": "Hooks instalados correctamente.",
            "vi": "Đã cài đặt Hook thành công.",
            "pt": "Hooks instalados com sucesso.",
        ],
        "hooksUninstalled": [
            "en": "Hooks uninstalled successfully.",
            "ko": "Hook이 제거되었습니다.",
            "zh": "Hook 已卸载。",
            "ja": "Hook をアンインストールしました。",
            "es": "Hooks desinstalados correctamente.",
            "vi": "Đã gỡ cài đặt Hook thành công.",
            "pt": "Hooks desinstalados com sucesso.",
        ],
        "hooksAlreadyInstalled": [
            "en": "Hooks are already installed.",
            "ko": "Hook이 이미 설치되어 있습니다.",
            "zh": "Hook 已安装。",
            "ja": "Hook はすでにインストールされています。",
            "es": "Los Hooks ya están instalados.",
            "vi": "Hook đã được cài đặt.",
            "pt": "Os Hooks já estão instalados.",
        ],
        "setupHooksPrompt": [
            "en": "Would you like to install Claude Code notification hooks?\nPlease select your settings.json file.",
            "ko": "Claude Code 알림 Hook을 설치하시겠습니까?\nsettings.json 파일을 선택해주세요.",
            "zh": "是否安装 Claude Code 通知 Hook？\n请选择 settings.json 文件。",
            "ja": "Claude Code 通知 Hook をインストールしますか？\nsettings.json ファイルを選択してください。",
            "es": "¿Desea instalar los Hooks de notificación de Claude Code?\nSeleccione el archivo settings.json.",
            "vi": "Bạn có muốn cài đặt Hook thông báo Claude Code không?\nVui lòng chọn tệp settings.json.",
            "pt": "Deseja instalar os Hooks de notificação do Claude Code?\nSelecione o arquivo settings.json.",
        ],
        "hookUpdateAvailable": [
            "en": "Hook update available. Would you like to update the notification hooks?",
            "ko": "Hook 업데이트가 있습니다. 알림 Hook을 업데이트하시겠습니까?",
            "zh": "Hook 有更新。是否更新通知 Hook？",
            "ja": "Hook の更新があります。通知 Hook を更新しますか？",
            "es": "Actualización de Hooks disponible. ¿Desea actualizar los Hooks de notificación?",
            "vi": "Có bản cập nhật Hook. Bạn có muốn cập nhật Hook thông báo không?",
            "pt": "Atualização de Hooks disponível. Deseja atualizar os Hooks de notificação?",
        ],
        "update": [
            "en": "Update",
            "ko": "업데이트",
            "zh": "更新",
            "ja": "更新",
            "es": "Actualizar",
            "vi": "Cập nhật",
            "pt": "Atualizar",
        ],
        "skip": [
            "en": "Skip",
            "ko": "건너뛰기",
            "zh": "跳过",
            "ja": "スキップ",
            "es": "Omitir",
            "vi": "Bỏ qua",
            "pt": "Pular",
        ],
        "install": [
            "en": "Install",
            "ko": "설치",
            "zh": "安装",
            "ja": "インストール",
            "es": "Instalar",
            "vi": "Cài đặt",
            "pt": "Instalar",
        ],
        "reviewChanges": [
            "en": "Review changes to settings.json:",
            "ko": "settings.json 변경사항을 확인하세요:",
            "zh": "查看 settings.json 的更改：",
            "ja": "settings.json の変更を確認してください：",
            "es": "Revise los cambios en settings.json:",
            "vi": "Xem lại thay đổi trong settings.json:",
            "pt": "Revise as alterações em settings.json:",
        ],
        "apply": [
            "en": "Apply",
            "ko": "적용",
            "zh": "应用",
            "ja": "適用",
            "es": "Aplicar",
            "vi": "Áp dụng",
            "pt": "Aplicar",
        ],
        "cancel": [
            "en": "Cancel",
            "ko": "취소",
            "zh": "取消",
            "ja": "キャンセル",
            "es": "Cancelar",
            "vi": "Hủy",
            "pt": "Cancelar",
        ],
        "hookError": [
            "en": "Failed to update settings file.",
            "ko": "설정 파일 업데이트에 실패했습니다.",
            "zh": "更新设置文件失败。",
            "ja": "設定ファイルの更新に失敗しました。",
            "es": "Error al actualizar el archivo de configuración.",
            "vi": "Không thể cập nhật tệp cài đặt.",
            "pt": "Falha ao atualizar o arquivo de configuração.",
        ],
        "quit": [
            "en": "Quit",
            "ko": "종료",
            "zh": "退出",
            "ja": "終了",
            "es": "Salir",
            "vi": "Thoát",
            "pt": "Sair",
        ],
    ]

    static func get(_ key: String) -> String {
        let lang = Language.current.rawValue
        return strings[key]?[lang] ?? strings[key]?["en"] ?? key
    }
}
