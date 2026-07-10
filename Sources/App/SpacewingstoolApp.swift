import SwiftUI
import AppKit
import UserNotifications

@main
@MainActor
struct SpacewingstoolApp: App {
    init() {
        AppSetup.perform()
    }

    private let settingsStore = SettingsStore.shared
    private let spaceStore = SpaceStore.shared
    private let menuBarImage: NSImage = {
        if let url = Bundle.module.url(forResource: "logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        let fallback = NSImage(systemSymbolName: "square.split.2x2", accessibilityDescription: "Spaces")!
        fallback.isTemplate = true
        return fallback
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(settingsStore)
                .environment(spaceStore)
        } label: {
            labelContent
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(settingsStore)
                .environment(spaceStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 400)
    }

    private var labelContent: some View {
        Image(nsImage: menuBarImage)
            .resizable()
            .frame(width: 18, height: 18)
    }
}

// MARK: - App lifecycle setup
enum AppSetup {

    static func perform() {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
            setAppIcon()
            requestNotificationPermission()
            beginBackgroundActivity()
            await initializeServices()
            checkAccessibilityPermission()
        }
    }

    @MainActor
    private static func setAppIcon() {
        if let iconPath = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconPath) {
            NSApp.applicationIconImage = iconImage
            iconImage.setName("AppIcon")
        }
    }

    private static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                Log.info("Notification permission granted")
            } else if let error = error {
                Log.warning("Notification permission denied: \(error.localizedDescription)")
            }
        }
    }

    private static func beginBackgroundActivity() {
        ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Spacewingstool workspace monitoring"
        )
    }

    @MainActor
    private static func initializeServices() async {
        await AIService.shared.initialize()
        await ContextAnalyzer.shared.startAnalysis()
        await startActivityDatabase()
        await startReadingTracker()
        await startWritingTracker()
        await startEmailTracker()
        await startMediaTracker()
        await startMeetingTracker()
        await CoachingService.shared.start()
        observeThermalChanges()
        await checkForUpdates()
    }

    @MainActor
    private static func checkForUpdates() async {
        await UpdateService.shared.checkForUpdates()
    }

    @MainActor
    private static func startReadingTracker() async {
        guard SettingsStore.shared.trackReading else {
            Log.info("Reading tracking disabled by privacy settings")
            return
        }
        await ReadingTracker.shared.start()
        Log.info("Reading tracker started")
    }

    @MainActor
    private static func startWritingTracker() async {
        guard SettingsStore.shared.trackWriting else {
            Log.info("Writing tracking disabled by privacy settings")
            return
        }
        await WritingTracker.shared.start()
        Log.info("Writing tracker started")
    }

    @MainActor
    private static func startEmailTracker() async {
        guard SettingsStore.shared.trackEmail else {
            Log.info("Email tracking disabled by privacy settings")
            return
        }
        await EmailTracker.shared.start()
        Log.info("Email tracker started")
    }

    @MainActor
    private static func startMediaTracker() async {
        guard SettingsStore.shared.trackMedia else {
            Log.info("Media tracking disabled by privacy settings")
            return
        }
        await MediaTracker.shared.start()
        Log.info("Media tracker started")
    }

    @MainActor
    private static func startMeetingTracker() async {
        guard SettingsStore.shared.trackMeetings else {
            Log.info("Meeting tracking disabled by privacy settings")
            return
        }
        await MeetingTracker.shared.start()
        Log.info("Meeting tracker started")
    }

    @MainActor
    private static func startActivityDatabase() async {
        let dbURL = databaseURL()
        let fm = FileManager.default
        let dbDir = dbURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dbDir.path) {
            try? fm.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }
        do {
            let database = try ActivityDatabase(url: dbURL)
            await ActivityTracker.shared.start(database: database)
            await SettingsTimelineManager.shared.setDatabase(database)
            await SettingsTimelineManager.shared.scheduleAutoSnapshot()
            Log.info("Activity database initialized at \(dbURL.path)")
        } catch {
            Log.error("Failed to initialize activity database: \(error.localizedDescription)")
        }
    }

    private static func databaseURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent(Constants.appBundleID)
        return appDir.appendingPathComponent("activity.sqlite")
    }

    @MainActor
    private static func observeThermalChanges() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { _ in
            let state = ProcessInfo.processInfo.thermalState
            Task { @MainActor in
                adjustPolling(for: state)
            }
        }
        adjustPolling(for: ProcessInfo.processInfo.thermalState)
    }

    @MainActor
    private static func adjustPolling(for state: ProcessInfo.ThermalState) {
        let interval: Double
        switch state {
        case .nominal: interval = SettingsStore.shared.pollingInterval
        case .fair: interval = min(SettingsStore.shared.pollingInterval * 1.5, 5.0)
        case .serious: interval = 5.0
        case .critical: interval = 10.0
        @unknown default: interval = SettingsStore.shared.pollingInterval
        }
        Task { await WindowMonitor.shared.setPollingInterval(interval) }
    }

    @MainActor
    private static func checkAccessibilityPermission() {
        let authorized = WindowMonitor.shared.isAccessibilityAuthorized
        if !authorized {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Spacewingstool needs Accessibility access to monitor your windows and switch workspaces. Please grant permission in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                WindowMonitor.shared.requestAccessibilityPermission()
            }
        }
    }
}

// Setup runs via SpacewingstoolApp.init() — safe after SwiftUI lifecycle init
