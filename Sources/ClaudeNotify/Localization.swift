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
