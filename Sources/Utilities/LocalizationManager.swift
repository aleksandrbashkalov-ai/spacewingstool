import SwiftUI

public enum AppLanguage: String, Sendable, CaseIterable, Codable {
    case en = "English"
    case es = "Español"
    case fr = "Français"
    case de = "Deutsch"
    case ar = "العربية"

    public var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en")
        case .es: return Locale(identifier: "es")
        case .fr: return Locale(identifier: "fr")
        case .de: return Locale(identifier: "de")
        case .ar: return Locale(identifier: "ar")
        }
    }

    public var isRTL: Bool { self == .ar }

    public var flag: String {
        switch self {
        case .en: return "🇺🇸"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .de: return "🇩🇪"
        case .ar: return "🇸🇦"
        }
    }
}

public enum L10n: String, Sendable, CaseIterable {
    case appName
    case general
    case spaces
    case shortcuts
    case privacy
    case launchAtLogin
    case autoSwitchSpaces
    case showMenuBarIcon
    case showNotifications
    case monitoring
    case pollingInterval
    case seconds
    case data
    case snapshotRetentionDays
    case noSpaces
    case createSpacesDescription
    case active
    case activeSpace
    case keyboardShortcuts
    case toggleWindow
    case nextSpace
    case previousSpace
    case captureSnapshot
    case quickSwitch
    case newSpace
    case autoSwitch
    case settings
    case quit
    case `switch`
    case switchTo
    case appCount
    case permissions
    case accessibility
    case screenRecording
    case microphone
    case fullDiskAccess
    case permAccessibilityDesc
    case permScreenRecordingDesc
    case permMicrophoneDesc
    case permNotificationsDesc
    case permFullDiskDesc
    case granted
    case fixInSettings
    case request
    case permFooter
    case readingTracking
    case trackReading
    case contentCapture
    case off
    case preview
    case full
    case writingTracking
    case trackWriting
    case metadataOnly
    case selectedText
    case emailTracking
    case trackEmail
    case bodyCapture
    case mediaTracking
    case trackMedia
    case meetingTracking
    case trackMeetings
    case recordMeetingAudio
    case smartFeatures
    case useAIEnhancement
    case aiType
    case localAIOnly
    case remoteAI
    case localPlusRemote
    case dataRetention
    case retainDataDays
    case olderDataDeleted
    case remoteAIConfig
    case endpointURL
    case apiKey
    case save
    case modelName
    case maxTokens
    case temperature
    case productivity
    case productivityFocused
    case productivityNeutral
    case productivityDistracted
    case productivityIdle
    case back
    case `continue`
    case getStarted
    case enableAutoSwitch
    case createFirstSpace
    case welcomeTitle
    case welcomeDesc
    case contextDetectionTitle
    case contextDetectionDesc
    case autoSwitchTitle
    case autoSwitchDesc
    case sessionMemoryTitle
    case sessionMemoryDesc
    case readyTitle
    case readyDesc
    case language
    case icloudSync
    case syncReading
    case syncWriting
    case syncEmail
    case syncMedia
    case syncMeetings
    case syncAll
    case lastSync
    case syncNow
    case never
    case timeline
    case coach
    case monitor
    case productivityCoach
    case refresh
    case recommendationsCount
    case noRecommendations
    case healthyPatterns
    case show
    case dismiss
    case todaysCoachingReport
    case deepWork
    case score
    case totalToday
    case sessions
    case peakHours
    case wellbeing
    case overtimeToday
    case nightWorkWeek
    case meetingOverload
    case avgWorkday
    case suggestedAction
    case detected
    case transparencyDashboard
    case liveMonitoring
    case currentlyMonitored
    case noActiveSession
    case noMediaPlaying
    case noActiveMeeting
    case disabled
    case deepWorkAnalysis
    case longestSession
    case contextSwitchesPerHour
    case burnoutSignals
    case riskLevel
    case weekendWorkWeek
    case privacyAndData
    case privacyConsentTitle
    case privacyConsentDesc
    case agreeAndContinue
    case dataDetails
    case deleteAllData
    case deleteAllDataConfirm
    case cancel
    case dataDeleted
    case dataManagement
    case deleteAllDataWarning
    case remoteAIWarningTitle
    case remoteAIWarningMessage
    case understandAndAgree
    case switchToLocalAI
    case exportMyData
    case noDataToExport

    public func localized(_ lang: AppLanguage) -> String {
        Translations.strings[lang]?[self] ?? Translations.strings[.en]?[self] ?? rawValue
    }
}

@MainActor
@Observable
public final class LocalizationManager {
    public static let shared = LocalizationManager()

    public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Constants.UserDefaultsKeys.language)
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.language)
        self.currentLanguage = AppLanguage.allCases.first(where: { $0.rawValue == saved }) ?? .en
    }

    public func translate(_ key: L10n, args: CVarArg...) -> String {
        let format = key.localized(currentLanguage)
        if args.isEmpty { return format }
        return String(format: format, arguments: args)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("com.spacewingstool.languageDidChange")
}

private enum Translations {
    static let strings: [AppLanguage: [L10n: String]] = [
        .en: [
            .appName: "Spacewingstool",
            .general: "General",
            .spaces: "Spaces",
            .shortcuts: "Shortcuts",
            .privacy: "Privacy",
            .launchAtLogin: "Launch at Login",
            .autoSwitchSpaces: "Auto-Switch Spaces",
            .showMenuBarIcon: "Show Menu Bar Icon",
            .showNotifications: "Show Notifications",
            .monitoring: "Monitoring",
            .pollingInterval: "Polling Interval",
            .seconds: "seconds",
            .data: "Data",
            .snapshotRetentionDays: "Snapshot retention: %d days",
            .noSpaces: "No Spaces",
            .createSpacesDescription: "Create spaces to manage your workspaces.",
            .active: "Active",
            .activeSpace: "Active Space",
            .keyboardShortcuts: "Keyboard Shortcuts",
            .toggleWindow: "Toggle Window",
            .nextSpace: "Next Space",
            .previousSpace: "Previous Space",
            .captureSnapshot: "Capture Snapshot",
            .quickSwitch: "Quick Switch",
            .newSpace: "New Space",
            .autoSwitch: "Auto-Switch",
            .settings: "Settings...",
            .quit: "Quit",
            .switch: "Switch",
            .switchTo: "Switch to \"%@\"?",
            .appCount: "%d apps",
            .permissions: "Permissions",
            .accessibility: "Accessibility",
            .screenRecording: "Screen Recording",
            .microphone: "Microphone",
            .fullDiskAccess: "Full Disk Access",
            .permAccessibilityDesc: "Required for app & window detection",
            .permScreenRecordingDesc: "Required for browser content capture",
            .permMicrophoneDesc: "Required for meeting transcription",
            .permNotificationsDesc: "For activity notifications",
            .permFullDiskDesc: "For file-level activity tracking",
            .granted: "Granted",
            .fixInSettings: "Fix in Settings",
            .request: "Request",
            .permFooter: "The Accessibility permission is required for activity tracking. Other permissions enable specific features.",
            .readingTracking: "Reading Tracking",
            .trackReading: "Track Reading Activity",
            .contentCapture: "Content Capture",
            .off: "Off",
            .preview: "Preview",
            .full: "Full",
            .writingTracking: "Writing Tracking",
            .trackWriting: "Track Writing Activity",
            .metadataOnly: "Metadata Only",
            .selectedText: "Selected Text",
            .emailTracking: "Email Tracking",
            .trackEmail: "Track Email Activity",
            .bodyCapture: "Body Capture",
            .mediaTracking: "Media Tracking",
            .trackMedia: "Track Media Playback",
            .meetingTracking: "Meeting Tracking",
            .trackMeetings: "Track Meetings",
            .recordMeetingAudio: "Record Meeting Audio",
            .smartFeatures: "Smart Features",
            .useAIEnhancement: "Use AI Enhancement",
            .aiType: "AI Type",
            .localAIOnly: "Local AI Only",
            .remoteAI: "Remote AI",
            .localPlusRemote: "Local + Remote",
            .dataRetention: "Data Retention",
            .retainDataDays: "Retain data for %d days",
            .olderDataDeleted: "Older data is automatically deleted.",
            .remoteAIConfig: "Remote AI Configuration",
            .endpointURL: "Endpoint URL",
            .apiKey: "API Key",
            .save: "Save",
            .modelName: "Model Name",
            .maxTokens: "Max Tokens: %d",
            .temperature: "Temperature: %.1f",
            .productivity: "Productivity: %@",
            .productivityFocused: "Focused",
            .productivityNeutral: "Neutral",
            .productivityDistracted: "Distracted",
            .productivityIdle: "Idle",
            .back: "Back",
            .continue: "Continue",
            .getStarted: "Get Started",
            .enableAutoSwitch: "Enable Auto-Switch",
            .createFirstSpace: "Create First Space",
            .welcomeTitle: "Welcome to Spacewingstool",
            .welcomeDesc: "Your intelligent workspace manager. Spacewingstool automatically creates, switches, and optimizes your workspaces based on what you're doing.",
            .contextDetectionTitle: "Smart Context Detection",
            .contextDetectionDesc: "Analyzes your open apps, active windows, calendar, and focus mode to understand your current context.",
            .autoSwitchTitle: "Auto-Switch Spaces",
            .autoSwitchDesc: "Enable auto-switch to let Spacewingstool automatically transition between spaces. No more manual window management.",
            .sessionMemoryTitle: "Session Memory",
            .sessionMemoryDesc: "Spacewingstool remembers your sessions. Capture snapshots of your workspace and restore them anytime.",
            .readyTitle: "Ready to Go",
            .readyDesc: "You're all set! Spacewingstool is running in your menu bar. Click the icon to manage spaces, view context, or access settings.",
            .language: "Language",
            .icloudSync: "iCloud Sync",
            .syncReading: "Sync Reading Activity",
            .syncWriting: "Sync Writing Activity",
            .syncEmail: "Sync Email Activity",
            .syncMedia: "Sync Media Activity",
            .syncMeetings: "Sync Meeting Activity",
            .syncAll: "Sync All",
            .lastSync: "Last sync: %@",
            .syncNow: "Sync Now",
            .never: "Never",
            .timeline: "Timeline",
            .coach: "Coach",
            .monitor: "Monitor",
            .productivityCoach: "Productivity Coach",
            .refresh: "Refresh",
            .recommendationsCount: "%d recommendations",
            .noRecommendations: "No Recommendations",
            .healthyPatterns: "Your work patterns look healthy. Check back later.",
            .show: "Show",
            .dismiss: "Dismiss",
            .todaysCoachingReport: "Today's Coaching Report",
            .deepWork: "Deep Work",
            .score: "Score",
            .totalToday: "Total Today",
            .sessions: "Sessions",
            .peakHours: "Peak Hours",
            .wellbeing: "Wellbeing",
            .overtimeToday: "Overtime Today",
            .nightWorkWeek: "Night Work (Week)",
            .meetingOverload: "Meeting Overload",
            .avgWorkday: "Avg Workday",
            .suggestedAction: "Suggested Action",
            .detected: "Detected %@",
            .transparencyDashboard: "Transparency Dashboard",
            .liveMonitoring: "Live Monitoring",
            .currentlyMonitored: "Currently Monitored",
            .noActiveSession: "No active session",
            .noMediaPlaying: "No media playing",
            .noActiveMeeting: "No active meeting",
            .disabled: "Disabled",
            .deepWorkAnalysis: "Deep Work Analysis",
            .longestSession: "Longest Session",
            .contextSwitchesPerHour: "Context Switches/hr",
            .burnoutSignals: "Burnout Signals",
            .riskLevel: "Risk Level",
            .weekendWorkWeek: "Weekend Work (Week)",
            .privacyAndData: "Privacy & Data",
            .privacyConsentTitle: "Privacy & Data Collection",
            .privacyConsentDesc: "Spacewingstool collects app activity data (open apps, window titles, browser URLs) to provide intelligent workspace features. It can also track reading, writing, email, media, and meetings when enabled.\n\nAll data is stored locally on your device unless you explicitly enable Remote AI. No data is shared without your consent.\n\nYou can change these settings at any time in Settings > Privacy.",
            .agreeAndContinue: "I Agree & Continue",
            .dataDetails: "See details about data collection",
            .deleteAllData: "Delete All Collected Data",
            .deleteAllDataConfirm: "Delete Everything",
            .cancel: "Cancel",
            .dataDeleted: "All data has been deleted.",
            .dataManagement: "Data Management",
            .deleteAllDataWarning: "This will permanently delete all collected activity data, summaries, and settings snapshots. This action cannot be undone.",
            .remoteAIWarningTitle: "Data Will Be Sent to Remote Server",
            .remoteAIWarningMessage: "Enabling Remote AI will send your activity data (apps used, window titles, URLs, reading/writing content) to the configured endpoint for analysis.\n\nPlease ensure the endpoint is trusted and complies with applicable privacy standards.",
            .understandAndAgree: "I Understand & Agree",
            .switchToLocalAI: "Switch to Local AI",
            .exportMyData: "Export My Data",
            .noDataToExport: "No data to export.",
        ],
        .es: [
            .appName: "Spacewingstool",
            .general: "General",
            .spaces: "Espacios",
            .shortcuts: "Atajos",
            .privacy: "Privacidad",
            .launchAtLogin: "Iniciar al acceder",
            .autoSwitchSpaces: "Cambio automático de espacios",
            .showMenuBarIcon: "Mostrar icono en la barra de menú",
            .showNotifications: "Mostrar notificaciones",
            .monitoring: "Monitoreo",
            .pollingInterval: "Intervalo de sondeo",
            .seconds: "segundos",
            .data: "Datos",
            .snapshotRetentionDays: "Retención de instantáneas: %d días",
            .noSpaces: "Sin espacios",
            .createSpacesDescription: "Crea espacios para gestionar tus áreas de trabajo.",
            .active: "Activo",
            .activeSpace: "Espacio activo",
            .keyboardShortcuts: "Atajos de teclado",
            .toggleWindow: "Alternar ventana",
            .nextSpace: "Siguiente espacio",
            .previousSpace: "Espacio anterior",
            .captureSnapshot: "Capturar instantánea",
            .quickSwitch: "Cambio rápido",
            .newSpace: "Nuevo espacio",
            .autoSwitch: "Cambio automático",
            .settings: "Ajustes...",
            .quit: "Salir",
            .switch: "Cambiar",
            .switchTo: "¿Cambiar a \"%@\"?",
            .appCount: "%d aplicaciones",
            .permissions: "Permisos",
            .accessibility: "Accesibilidad",
            .screenRecording: "Grabación de pantalla",
            .microphone: "Micrófono",
            .fullDiskAccess: "Acceso total al disco",
            .permAccessibilityDesc: "Requerido para detección de apps y ventanas",
            .permScreenRecordingDesc: "Requerido para captura de contenido del navegador",
            .permMicrophoneDesc: "Requerido para transcripción de reuniones",
            .permNotificationsDesc: "Para notificaciones de actividad",
            .permFullDiskDesc: "Para seguimiento a nivel de archivos",
            .granted: "Concedido",
            .fixInSettings: "Arreglar en Ajustes",
            .request: "Solicitar",
            .permFooter: "El permiso de Accesibilidad es necesario para el seguimiento de actividad. Otros permisos habilitan funciones específicas.",
            .readingTracking: "Seguimiento de lectura",
            .trackReading: "Rastrear actividad de lectura",
            .contentCapture: "Captura de contenido",
            .off: "Desactivado",
            .preview: "Vista previa",
            .full: "Completo",
            .writingTracking: "Seguimiento de escritura",
            .trackWriting: "Rastrear actividad de escritura",
            .metadataOnly: "Solo metadatos",
            .selectedText: "Texto seleccionado",
            .emailTracking: "Seguimiento de correo",
            .trackEmail: "Rastrear actividad de correo",
            .bodyCapture: "Captura de cuerpo",
            .mediaTracking: "Seguimiento de medios",
            .trackMedia: "Rastrear reproducción de medios",
            .meetingTracking: "Seguimiento de reuniones",
            .trackMeetings: "Rastrear reuniones",
            .recordMeetingAudio: "Grabar audio de reuniones",
            .smartFeatures: "Funciones inteligentes",
            .useAIEnhancement: "Usar mejora con IA",
            .aiType: "Tipo de IA",
            .localAIOnly: "Solo IA local",
            .remoteAI: "IA remota",
            .localPlusRemote: "Local + Remota",
            .dataRetention: "Retención de datos",
            .retainDataDays: "Conservar datos por %d días",
            .olderDataDeleted: "Los datos más antiguos se eliminan automáticamente.",
            .remoteAIConfig: "Configuración de IA remota",
            .endpointURL: "URL del endpoint",
            .apiKey: "Clave API",
            .save: "Guardar",
            .modelName: "Nombre del modelo",
            .maxTokens: "Máx. tokens: %d",
            .temperature: "Temperatura: %.1f",
            .productivity: "Productividad: %@",
            .productivityFocused: "Enfocado",
            .productivityNeutral: "Neutral",
            .productivityDistracted: "Distraído",
            .productivityIdle: "Inactivo",
            .back: "Atrás",
            .continue: "Continuar",
            .getStarted: "Comenzar",
            .enableAutoSwitch: "Activar cambio automático",
            .createFirstSpace: "Crear primer espacio",
            .welcomeTitle: "Bienvenido a Spacewingstool",
            .welcomeDesc: "Su gestor inteligente de espacios de trabajo. Spacewingstool crea, cambia y optimiza automáticamente sus espacios según lo que esté haciendo.",
            .contextDetectionTitle: "Detección inteligente de contexto",
            .contextDetectionDesc: "Analiza sus apps abiertas, ventanas activas, calendario y modo de enfoque para entender su contexto actual.",
            .autoSwitchTitle: "Cambio automático de espacios",
            .autoSwitchDesc: "Active el cambio automático para que Spacewingstool transicione entre espacios sin intervención manual.",
            .sessionMemoryTitle: "Memoria de sesión",
            .sessionMemoryDesc: "Spacewingstool recuerda sus sesiones. Capture instantáneas de su espacio de trabajo y restáurelas cuando quiera.",
            .readyTitle: "Listo para usar",
            .readyDesc: "¡Todo listo! Spacewingstool se ejecuta en la barra de menú. Haga clic en el icono para gestionar espacios, ver el contexto o acceder a ajustes.",
            .language: "Idioma",
            .icloudSync: "Sincronización iCloud",
            .syncReading: "Sincronizar actividad de lectura",
            .syncWriting: "Sincronizar actividad de escritura",
            .syncEmail: "Sincronizar actividad de correo",
            .syncMedia: "Sincronizar actividad multimedia",
            .syncMeetings: "Sincronizar actividad de reuniones",
            .syncAll: "Sincronizar todo",
            .lastSync: "Última sincronización: %@",
            .syncNow: "Sincronizar ahora",
            .never: "Nunca",
            .timeline: "Línea de tiempo",
            .coach: "Entrenador",
            .monitor: "Monitor",
            .productivityCoach: "Entrenador de productividad",
            .refresh: "Actualizar",
            .recommendationsCount: "%d recomendaciones",
            .noRecommendations: "Sin recomendaciones",
            .healthyPatterns: "Tus patrones de trabajo se ven saludables. Vuelve más tarde.",
            .show: "Mostrar",
            .dismiss: "Descartar",
            .todaysCoachingReport: "Informe de hoy",
            .deepWork: "Trabajo profundo",
            .score: "Puntaje",
            .totalToday: "Total hoy",
            .sessions: "Sesiones",
            .peakHours: "Horas pico",
            .wellbeing: "Bienestar",
            .overtimeToday: "Horas extra hoy",
            .nightWorkWeek: "Trabajo nocturno (semana)",
            .meetingOverload: "Sobrecarga de reuniones",
            .avgWorkday: "Jornada promedio",
            .suggestedAction: "Acción sugerida",
            .detected: "Detectado %@",
            .transparencyDashboard: "Panel de transparencia",
            .liveMonitoring: "Monitoreo en vivo",
            .currentlyMonitored: "Monitoreado actualmente",
            .noActiveSession: "Sin sesión activa",
            .noMediaPlaying: "Sin reproducción",
            .noActiveMeeting: "Sin reunión activa",
            .disabled: "Desactivado",
            .deepWorkAnalysis: "Análisis de trabajo profundo",
            .longestSession: "Sesión más larga",
            .contextSwitchesPerHour: "Cambios de contexto/h",
            .burnoutSignals: "Señales de agotamiento",
            .riskLevel: "Nivel de riesgo",
            .weekendWorkWeek: "Trabajo en fin de semana",
            .privacyAndData: "Privacidad y datos",
            .privacyConsentTitle: "Privacidad y recopilación de datos",
            .privacyConsentDesc: "Spacewingstool recopila datos de actividad de la aplicación (aplicaciones abiertas, títulos de ventanas, URL del navegador) para proporcionar espacios de trabajo inteligentes. También puede rastrear lectura, escritura, correo electrónico, medios y reuniones si está habilitado.\n\nTodos los datos se almacenan localmente en su dispositivo a menos que habilite explícitamente la IA remota. No se comparten datos sin su consentimiento.\n\nPuede cambiar estas configuraciones en cualquier momento en Ajustes > Privacidad.",
            .agreeAndContinue: "Acepto y continuar",
            .dataDetails: "Ver detalles sobre la recopilación de datos",
            .deleteAllData: "Eliminar todos los datos recopilados",
            .deleteAllDataConfirm: "Eliminar todo",
            .cancel: "Cancelar",
            .dataDeleted: "Todos los datos han sido eliminados.",
            .dataManagement: "Gestión de datos",
            .deleteAllDataWarning: "Esto eliminará permanentemente todos los datos de actividad recopilados, resúmenes y capturas de configuración. Esta acción no se puede deshacer.",
            .remoteAIWarningTitle: "Los datos se enviarán a un servidor remoto",
            .remoteAIWarningMessage: "Al habilitar la IA remota, sus datos de actividad (aplicaciones utilizadas, títulos de ventanas, URL, contenido de lectura/escritura) se enviarán al punto final configurado para su análisis.\n\nAsegúrese de que el punto final sea de confianza y cumpla con los estándares de privacidad aplicables.",
            .understandAndAgree: "Entiendo y acepto",
            .switchToLocalAI: "Cambiar a IA local",
            .exportMyData: "Exportar mis datos",
            .noDataToExport: "No hay datos para exportar.",
        ],
        .fr: [
            .appName: "Spacewingstool",
            .general: "Général",
            .spaces: "Espaces",
            .shortcuts: "Raccourcis",
            .privacy: "Confidentialité",
            .launchAtLogin: "Lancer à la connexion",
            .autoSwitchSpaces: "Commutation automatique des espaces",
            .showMenuBarIcon: "Afficher l'icône dans la barre de menu",
            .showNotifications: "Afficher les notifications",
            .monitoring: "Surveillance",
            .pollingInterval: "Intervalle de sondage",
            .seconds: "secondes",
            .data: "Données",
            .snapshotRetentionDays: "Rétention des instantanés : %d jours",
            .noSpaces: "Aucun espace",
            .createSpacesDescription: "Créez des espaces pour gérer vos espaces de travail.",
            .active: "Actif",
            .activeSpace: "Espace actif",
            .keyboardShortcuts: "Raccourcis clavier",
            .toggleWindow: "Basculer la fenêtre",
            .nextSpace: "Espace suivant",
            .previousSpace: "Espace précédent",
            .captureSnapshot: "Capturer un instantané",
            .quickSwitch: "Commutation rapide",
            .newSpace: "Nouvel espace",
            .autoSwitch: "Commutation automatique",
            .settings: "Paramètres...",
            .quit: "Quitter",
            .switch: "Basculer",
            .switchTo: "Basculer vers \"%@\" ?",
            .appCount: "%d applications",
            .permissions: "Autorisations",
            .accessibility: "Accessibilité",
            .screenRecording: "Enregistrement d'écran",
            .microphone: "Microphone",
            .fullDiskAccess: "Accès complet au disque",
            .permAccessibilityDesc: "Requis pour la détection des apps et fenêtres",
            .permScreenRecordingDesc: "Requis pour la capture du contenu du navigateur",
            .permMicrophoneDesc: "Requis pour la transcription des réunions",
            .permNotificationsDesc: "Pour les notifications d'activité",
            .permFullDiskDesc: "Pour le suivi au niveau des fichiers",
            .granted: "Autorisé",
            .fixInSettings: "Corriger dans les réglages",
            .request: "Demander",
            .permFooter: "L'autorisation d'accessibilité est requise pour le suivi d'activité. Les autres autorisations activent des fonctionnalités spécifiques.",
            .readingTracking: "Suivi de lecture",
            .trackReading: "Suivre l'activité de lecture",
            .contentCapture: "Capture de contenu",
            .off: "Désactivé",
            .preview: "Aperçu",
            .full: "Complet",
            .writingTracking: "Suivi d'écriture",
            .trackWriting: "Suivre l'activité d'écriture",
            .metadataOnly: "Métadonnées uniquement",
            .selectedText: "Texte sélectionné",
            .emailTracking: "Suivi des e-mails",
            .trackEmail: "Suivre l'activité e-mail",
            .bodyCapture: "Capture du corps",
            .mediaTracking: "Suivi des médias",
            .trackMedia: "Suivre la lecture multimédia",
            .meetingTracking: "Suivi des réunions",
            .trackMeetings: "Suivre les réunions",
            .recordMeetingAudio: "Enregistrer l'audio des réunions",
            .smartFeatures: "Fonctionnalités intelligentes",
            .useAIEnhancement: "Utiliser l'amélioration par IA",
            .aiType: "Type d'IA",
            .localAIOnly: "IA locale uniquement",
            .remoteAI: "IA à distance",
            .localPlusRemote: "Locale + Distante",
            .dataRetention: "Conservation des données",
            .retainDataDays: "Conserver les données %d jours",
            .olderDataDeleted: "Les données plus anciennes sont automatiquement supprimées.",
            .remoteAIConfig: "Configuration IA distante",
            .endpointURL: "URL du point d'accès",
            .apiKey: "Clé API",
            .save: "Enregistrer",
            .modelName: "Nom du modèle",
            .maxTokens: "Max. jetons : %d",
            .temperature: "Température : %.1f",
            .productivity: "Productivité : %@",
            .productivityFocused: "Concentré",
            .productivityNeutral: "Neutre",
            .productivityDistracted: "Distrait",
            .productivityIdle: "Inactif",
            .back: "Retour",
            .continue: "Continuer",
            .getStarted: "Commencer",
            .enableAutoSwitch: "Activer la commutation automatique",
            .createFirstSpace: "Créer un premier espace",
            .welcomeTitle: "Bienvenue sur Spacewingstool",
            .welcomeDesc: "Votre gestionnaire intelligent d'espaces de travail. Spacewingstool crée, change et optimise automatiquement vos espaces selon ce que vous faites.",
            .contextDetectionTitle: "Détection intelligente du contexte",
            .contextDetectionDesc: "Analyse vos applications ouvertes, fenêtres actives, calendrier et mode de concentration pour comprendre votre contexte actuel.",
            .autoSwitchTitle: "Commutation automatique des espaces",
            .autoSwitchDesc: "Activez la commutation automatique pour que Spacewingstool transitionne entre les espaces sans gestion manuelle.",
            .sessionMemoryTitle: "Mémoire de session",
            .sessionMemoryDesc: "Spacewingstool se souvient de vos sessions. Capturez des instantanés de votre espace de travail et restaurez-les à tout moment.",
            .readyTitle: "Prêt à l'emploi",
            .readyDesc: "Vous êtes prêt ! Spacewingstool s'exécute dans votre barre de menu. Cliquez sur l'icône pour gérer les espaces, voir le contexte ou accéder aux paramètres.",
            .language: "Langue",
            .icloudSync: "Synchronisation iCloud",
            .syncReading: "Synchroniser l'activité de lecture",
            .syncWriting: "Synchroniser l'activité d'écriture",
            .syncEmail: "Synchroniser l'activité e-mail",
            .syncMedia: "Synchroniser l'activité multimédia",
            .syncMeetings: "Synchroniser l'activité des réunions",
            .syncAll: "Tout synchroniser",
            .lastSync: "Dernière synchro : %@",
            .syncNow: "Synchroniser maintenant",
            .never: "Jamais",
            .timeline: "Chronologie",
            .coach: "Coach",
            .monitor: "Moniteur",
            .productivityCoach: "Coach de productivité",
            .refresh: "Actualiser",
            .recommendationsCount: "%d recommandations",
            .noRecommendations: "Aucune recommandation",
            .healthyPatterns: "Vos habitudes de travail semblent saines. Revenez plus tard.",
            .show: "Afficher",
            .dismiss: "Ignorer",
            .todaysCoachingReport: "Rapport du jour",
            .deepWork: "Travail profond",
            .score: "Score",
            .totalToday: "Total aujourd'hui",
            .sessions: "Sessions",
            .peakHours: "Heures de pointe",
            .wellbeing: "Bien-être",
            .overtimeToday: "Heures sup. aujourd'hui",
            .nightWorkWeek: "Travail de nuit (semaine)",
            .meetingOverload: "Surcharge de réunions",
            .avgWorkday: "Journée moyenne",
            .suggestedAction: "Action suggérée",
            .detected: "Détecté %@",
            .transparencyDashboard: "Tableau de transparence",
            .liveMonitoring: "Surveillance en direct",
            .currentlyMonitored: "Actuellement surveillé",
            .noActiveSession: "Aucune session active",
            .noMediaPlaying: "Aucun média en cours",
            .noActiveMeeting: "Aucune réunion active",
            .disabled: "Désactivé",
            .deepWorkAnalysis: "Analyse du travail profond",
            .longestSession: "Session la plus longue",
            .contextSwitchesPerHour: "Changements de contexte/h",
            .burnoutSignals: "Signaux d'épuisement",
            .riskLevel: "Niveau de risque",
            .weekendWorkWeek: "Travail le week-end",
        ],
        .de: [
            .appName: "Spacewingstool",
            .general: "Allgemein",
            .spaces: "Bereiche",
            .shortcuts: "Tastenkürzel",
            .privacy: "Datenschutz",
            .launchAtLogin: "Beim Anmelden starten",
            .autoSwitchSpaces: "Automatischer Bereichswechsel",
            .showMenuBarIcon: "Menüleistensymbol anzeigen",
            .showNotifications: "Benachrichtigungen anzeigen",
            .monitoring: "Überwachung",
            .pollingInterval: "Abfrageintervall",
            .seconds: "Sekunden",
            .data: "Daten",
            .snapshotRetentionDays: "Aufbewahrung von Schnappschüssen: %d Tage",
            .noSpaces: "Keine Bereiche",
            .createSpacesDescription: "Erstellen Sie Bereiche, um Ihre Arbeitsbereiche zu verwalten.",
            .active: "Aktiv",
            .activeSpace: "Aktiver Bereich",
            .keyboardShortcuts: "Tastenkürzel",
            .toggleWindow: "Fenster umschalten",
            .nextSpace: "Nächster Bereich",
            .previousSpace: "Vorheriger Bereich",
            .captureSnapshot: "Schnappschuss aufnehmen",
            .quickSwitch: "Schnellwechsel",
            .newSpace: "Neuer Bereich",
            .autoSwitch: "Automatisch wechseln",
            .settings: "Einstellungen...",
            .quit: "Beenden",
            .switch: "Wechseln",
            .switchTo: "Zu \"%@\" wechseln?",
            .appCount: "%d Apps",
            .permissions: "Berechtigungen",
            .accessibility: "Bedienungshilfen",
            .screenRecording: "Bildschirmaufzeichnung",
            .microphone: "Mikrofon",
            .fullDiskAccess: "Vollzugriff auf Festplatte",
            .permAccessibilityDesc: "Erforderlich für App- und Fenstererkennung",
            .permScreenRecordingDesc: "Erforderlich für Browser-Inhaltserfassung",
            .permMicrophoneDesc: "Erforderlich für Besprechungstranskription",
            .permNotificationsDesc: "Für Aktivitätsbenachrichtigungen",
            .permFullDiskDesc: "Für dateibasierte Aktivitätsverfolgung",
            .granted: "Gewährt",
            .fixInSettings: "In Einstellungen beheben",
            .request: "Anfordern",
            .permFooter: "Die Berechtigung für Bedienungshilfen ist für die Aktivitätsverfolgung erforderlich. Andere Berechtigungen aktivieren spezifische Funktionen.",
            .readingTracking: "Leseaktivität verfolgen",
            .trackReading: "Leseaktivität aufzeichnen",
            .contentCapture: "Inhaltserfassung",
            .off: "Aus",
            .preview: "Vorschau",
            .full: "Vollständig",
            .writingTracking: "Schreibaktivität verfolgen",
            .trackWriting: "Schreibaktivität aufzeichnen",
            .metadataOnly: "Nur Metadaten",
            .selectedText: "Ausgewählter Text",
            .emailTracking: "E-Mail-Verfolgung",
            .trackEmail: "E-Mail-Aktivität aufzeichnen",
            .bodyCapture: "Inhaltserfassung",
            .mediaTracking: "Medienverfolgung",
            .trackMedia: "Medienwiedergabe aufzeichnen",
            .meetingTracking: "Besprechungsverfolgung",
            .trackMeetings: "Besprechungen aufzeichnen",
            .recordMeetingAudio: "Besprechungsaudio aufnehmen",
            .smartFeatures: "Intelligente Funktionen",
            .useAIEnhancement: "KI-Verbesserung verwenden",
            .aiType: "KI-Typ",
            .localAIOnly: "Nur lokale KI",
            .remoteAI: "Entfernte KI",
            .localPlusRemote: "Lokal + Entfernt",
            .dataRetention: "Datenaufbewahrung",
            .retainDataDays: "Daten %d Tage aufbewahren",
            .olderDataDeleted: "Ältere Daten werden automatisch gelöscht.",
            .remoteAIConfig: "Konfiguration für entfernte KI",
            .endpointURL: "Endpunkt-URL",
            .apiKey: "API-Schlüssel",
            .save: "Speichern",
            .modelName: "Modellname",
            .maxTokens: "Max. Token: %d",
            .temperature: "Temperatur: %.1f",
            .productivity: "Produktivität: %@",
            .productivityFocused: "Konzentriert",
            .productivityNeutral: "Neutral",
            .productivityDistracted: "Ablenkbar",
            .productivityIdle: "Inaktiv",
            .back: "Zurück",
            .continue: "Weiter",
            .getStarted: "Loslegen",
            .enableAutoSwitch: "Automatischen Wechsel aktivieren",
            .createFirstSpace: "Ersten Bereich erstellen",
            .welcomeTitle: "Willkommen bei Spacewingstool",
            .welcomeDesc: "Ihr intelligenter Arbeitsbereichs-Manager. Spacewingstool erstellt, wechselt und optimiert automatisch Ihre Bereiche basierend auf Ihrer aktuellen Tätigkeit.",
            .contextDetectionTitle: "Intelligente Kontexterkennung",
            .contextDetectionDesc: "Analysiert Ihre offenen Apps, aktiven Fenster, Kalender und den Fokus-Modus, um Ihren aktuellen Kontext zu verstehen.",
            .autoSwitchTitle: "Automatischer Bereichswechsel",
            .autoSwitchDesc: "Aktivieren Sie den automatischen Wechsel, damit Spacewingstool nahtlos zwischen Bereichen wechselt. Kein manuelles Fenster-Management mehr.",
            .sessionMemoryTitle: "Sitzungsspeicher",
            .sessionMemoryDesc: "Spacewingstool merkt sich Ihre Sitzungen. Machen Sie Schnappschüsse Ihres Arbeitsbereichs und stellen Sie sie jederzeit wieder her.",
            .readyTitle: "Bereit zum Start",
            .readyDesc: "Sie sind bereit! Spacewingstool läuft in Ihrer Menüleiste. Klicken Sie auf das Symbol, um Bereiche zu verwalten, Kontext anzuzeigen oder auf Einstellungen zuzugreifen.",
            .language: "Sprache",
            .icloudSync: "iCloud-Synchronisierung",
            .syncReading: "Leseaktivität synchronisieren",
            .syncWriting: "Schreibaktivität synchronisieren",
            .syncEmail: "E-Mail-Aktivität synchronisieren",
            .syncMedia: "Medienaktivität synchronisieren",
            .syncMeetings: "Besprechungsaktivität synchronisieren",
            .syncAll: "Alle synchronisieren",
            .lastSync: "Letzte Synchronisierung: %@",
            .syncNow: "Jetzt synchronisieren",
            .never: "Nie",
            .timeline: "Zeitleiste",
            .coach: "Coach",
            .monitor: "Monitor",
            .productivityCoach: "Produktivitätscoach",
            .refresh: "Aktualisieren",
            .recommendationsCount: "%d Empfehlungen",
            .noRecommendations: "Keine Empfehlungen",
            .healthyPatterns: "Ihre Arbeitsmuster sehen gesund aus. Später nochmal vorbeischauen.",
            .show: "Anzeigen",
            .dismiss: "Verwerfen",
            .todaysCoachingReport: "Heutiger Coaching-Bericht",
            .deepWork: "Tiefenarbeit",
            .score: "Punktzahl",
            .totalToday: "Heute insgesamt",
            .sessions: "Sitzungen",
            .peakHours: "Spitzenzeiten",
            .wellbeing: "Wohlbefinden",
            .overtimeToday: "Überstunden heute",
            .nightWorkWeek: "Nachtarbeit (Woche)",
            .meetingOverload: "Besprechungsüberlastung",
            .avgWorkday: "Durchschn. Arbeitstag",
            .suggestedAction: "Vorgeschlagene Aktion",
            .detected: "Erkannt %@",
            .transparencyDashboard: "Transparenz-Dashboard",
            .liveMonitoring: "Live-Überwachung",
            .currentlyMonitored: "Derzeit überwacht",
            .noActiveSession: "Keine aktive Sitzung",
            .noMediaPlaying: "Keine Medienwiedergabe",
            .noActiveMeeting: "Keine aktive Besprechung",
            .disabled: "Deaktiviert",
            .deepWorkAnalysis: "Tiefenarbeitsanalyse",
            .longestSession: "Längste Sitzung",
            .contextSwitchesPerHour: "Kontextwechsel/Std",
            .burnoutSignals: "Burnout-Signale",
            .riskLevel: "Risikostufe",
            .weekendWorkWeek: "Wochenendarbeit",
        ],
        .ar: [
            .appName: "Spacewingstool",
            .general: "عام",
            .spaces: "المساحات",
            .shortcuts: "الاختصارات",
            .privacy: "الخصوصية",
            .launchAtLogin: "تشغيل عند تسجيل الدخول",
            .autoSwitchSpaces: "التبديل التلقائي للمساحات",
            .showMenuBarIcon: "إظهار أيقونة شريط القوائم",
            .showNotifications: "إظهار الإشعارات",
            .monitoring: "المراقبة",
            .pollingInterval: "فترة الاستقصاء",
            .seconds: "ثوانٍ",
            .data: "البيانات",
            .snapshotRetentionDays: "الاحتفاظ باللقطات: %d يومًا",
            .noSpaces: "لا توجد مساحات",
            .createSpacesDescription: "أنشئ مساحات لإدارة أماكن عملك.",
            .active: "نشط",
            .activeSpace: "المساحة النشطة",
            .keyboardShortcuts: "اختصارات لوحة المفاتيح",
            .toggleWindow: "تبديل النافذة",
            .nextSpace: "المساحة التالية",
            .previousSpace: "المساحة السابقة",
            .captureSnapshot: "التقاط لقطة",
            .quickSwitch: "تبديل سريع",
            .newSpace: "مساحة جديدة",
            .autoSwitch: "التبديل التلقائي",
            .settings: "الإعدادات...",
            .quit: "خروج",
            .switch: "تبديل",
            .switchTo: "التبديل إلى \"%@\"؟",
            .appCount: "%d تطبيقات",
            .permissions: "الأذونات",
            .accessibility: "إمكانية الوصول",
            .screenRecording: "تسجيل الشاشة",
            .microphone: "الميكروفون",
            .fullDiskAccess: "الوصول الكامل للقرص",
            .permAccessibilityDesc: "مطلوب للكشف عن التطبيقات والنوافذ",
            .permScreenRecordingDesc: "مطلوب لالتقاط محتوى المتصفح",
            .permMicrophoneDesc: "مطلوب لنسخ الاجتماعات",
            .permNotificationsDesc: "لإشعارات النشاط",
            .permFullDiskDesc: "لتتبع النشاط على مستوى الملفات",
            .granted: "ممنوح",
            .fixInSettings: "إصلاح في الإعدادات",
            .request: "طلب",
            .permFooter: "إذن إمكانية الوصول مطلوب لتتبع النشاط. الأذونات الأخرى تتيح ميزات محددة.",
            .readingTracking: "تتبع القراءة",
            .trackReading: "تتبع نشاط القراءة",
            .contentCapture: "التقاط المحتوى",
            .off: "إيقاف",
            .preview: "معاينة",
            .full: "كامل",
            .writingTracking: "تتبع الكتابة",
            .trackWriting: "تتبع نشاط الكتابة",
            .metadataOnly: "البيانات الوصفية فقط",
            .selectedText: "النص المحدد",
            .emailTracking: "تتبع البريد الإلكتروني",
            .trackEmail: "تتبع نشاط البريد الإلكتروني",
            .bodyCapture: "التقاط المحتوى",
            .mediaTracking: "تتبع الوسائط",
            .trackMedia: "تتبع تشغيل الوسائط",
            .meetingTracking: "تتبع الاجتماعات",
            .trackMeetings: "تتبع الاجتماعات",
            .recordMeetingAudio: "تسجيل صوت الاجتماع",
            .smartFeatures: "ميزات ذكية",
            .useAIEnhancement: "استخدام تحسين الذكاء الاصطناعي",
            .aiType: "نوع الذكاء الاصطناعي",
            .localAIOnly: "محلي فقط",
            .remoteAI: "عن بُعد",
            .localPlusRemote: "محلي + عن بُعد",
            .dataRetention: "الاحتفاظ بالبيانات",
            .retainDataDays: "الاحتفاظ بالبيانات لمدة %d يومًا",
            .olderDataDeleted: "يتم حذف البيانات الأقدم تلقائيًا.",
            .remoteAIConfig: "إعدادات الذكاء الاصطناعي عن بُعد",
            .endpointURL: "رابط نقطة النهاية",
            .apiKey: "مفتاح API",
            .save: "حفظ",
            .modelName: "اسم النموذج",
            .maxTokens: "الحد الأقصى للرموز: %d",
            .temperature: "درجة الحرارة: %.1f",
            .productivity: "الإنتاجية: %@",
            .productivityFocused: "مركز",
            .productivityNeutral: "محايد",
            .productivityDistracted: "مشتت",
            .productivityIdle: "خامل",
            .back: "رجوع",
            .continue: "متابعة",
            .getStarted: "ابدأ",
            .enableAutoSwitch: "تفعيل التبديل التلقائي",
            .createFirstSpace: "إنشاء المساحة الأولى",
            .welcomeTitle: "مرحبًا بك في Spacewingstool",
            .welcomeDesc: "مدير مساحة العمل الذكي الخاص بك. يقوم Spacewingstool بإنشاء المساحات وتبديلها وتحسينها تلقائيًا بناءً على ما تفعله.",
            .contextDetectionTitle: "الكشف الذكي للسياق",
            .contextDetectionDesc: "يحلل تطبيقاتك المفتوحة والنوافذ النشطة والتقويم ووضع التركيز لفهم سياقك الحالي.",
            .autoSwitchTitle: "التبديل التلقائي للمساحات",
            .autoSwitchDesc: "قم بتمكين التبديل التلقائي للسماح لـ Spacewingstool بالانتقال بين المساحات تلقائيًا. لا مزيد من إدارة النوافذ اليدوية.",
            .sessionMemoryTitle: "ذاكرة الجلسة",
            .sessionMemoryDesc: "يتذكر Spacewingstool جلساتك. التقط لقطات لمساحة عملك واستعدها في أي وقت.",
            .readyTitle: "جاهز للانطلاق",
            .readyDesc: "كل شيء جاهز! يعمل Spacewingstool في شريط القوائم. انقر على الأيقونة لإدارة المساحات أو عرض السياق أو الوصول إلى الإعدادات.",
            .language: "اللغة",
            .icloudSync: "مزامنة iCloud",
            .syncReading: "مزامنة نشاط القراءة",
            .syncWriting: "مزامنة نشاط الكتابة",
            .syncEmail: "مزامنة نشاط البريد الإلكتروني",
            .syncMedia: "مزامنة نشاط الوسائط",
            .syncMeetings: "مزامنة نشاط الاجتماعات",
            .syncAll: "مزامنة الكل",
            .lastSync: "آخر مزامنة: %@",
            .syncNow: "مزامنة الآن",
            .never: "أبدًا",
            .timeline: "الجدول الزمني",
            .coach: "المدرب",
            .monitor: "المراقب",
            .productivityCoach: "مدرب الإنتاجية",
            .refresh: "تحديث",
            .recommendationsCount: "%d توصية",
            .noRecommendations: "لا توجد توصيات",
            .healthyPatterns: "أنماط عملك تبدو صحية. تحقق لاحقًا.",
            .show: "إظهار",
            .dismiss: "تجاهل",
            .todaysCoachingReport: "تقرير التدريب اليوم",
            .deepWork: "العمل العميق",
            .score: "النتيجة",
            .totalToday: "المجموع اليوم",
            .sessions: "الجلسات",
            .peakHours: "ساعات الذروة",
            .wellbeing: "الرفاهية",
            .overtimeToday: "العمل الإضافي اليوم",
            .nightWorkWeek: "العمل الليلي (أسبوع)",
            .meetingOverload: "الحمل الزائد للاجتماعات",
            .avgWorkday: "متوسط يوم العمل",
            .suggestedAction: "الإجراء المقترح",
            .detected: "تم الكشف %@",
            .transparencyDashboard: "لوحة الشفافية",
            .liveMonitoring: "المراقبة المباشرة",
            .currentlyMonitored: "المراقبة حاليًا",
            .noActiveSession: "لا توجد جلسة نشطة",
            .noMediaPlaying: "لا يوجد وسائط قيد التشغيل",
            .noActiveMeeting: "لا يوجد اجتماع نشط",
            .disabled: "معطل",
            .deepWorkAnalysis: "تحليل العمل العميق",
            .longestSession: "أطول جلسة",
            .contextSwitchesPerHour: "تبديل السياق/ساعة",
            .burnoutSignals: "إشارات الإرهاق",
            .riskLevel: "مستوى المخاطرة",
            .weekendWorkWeek: "عمل عطلة نهاية الأسبوع",
        ],
    ]
}
