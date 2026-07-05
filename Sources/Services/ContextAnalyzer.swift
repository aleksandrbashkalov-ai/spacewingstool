import EventKit
import Foundation
import AppKit

public actor ContextAnalyzer {
    public static let shared = ContextAnalyzer()

    private let windowMonitor = WindowMonitor.shared
    private var lastDetectedContext: DetectedContext?
    private var analysisTask: Task<Void, Never>?
    private var hasCalendarAccess = false

    private let (contextStream, contextContinuation) = AsyncStream<DetectedContext>.makeStream()
    public nonisolated var contextUpdates: AsyncStream<DetectedContext> { contextStream }

    public func startAnalysis() {
        Task { await windowMonitor.startMonitoring() }
        Task { await requestCalendarAccess() }

        analysisTask = Task { [weak self] in
            guard let self = self else { return }
            for await windows in self.windowMonitor.windows {
                await self.analyze(windows: windows)
            }
        }
    }

    public func stopAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    public func requestCalendarAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined || status == .fullAccess || status == .writeOnly else {
            hasCalendarAccess = status == .fullAccess
            return
        }

        do {
            let eventStore = EKEventStore()
            let granted = try await eventStore.requestFullAccessToEvents()
            hasCalendarAccess = granted
            if granted {
                Log.info("Calendar full access granted")
            }
        } catch {
            Log.warning("Calendar access denied: \(error.localizedDescription)")
        }
    }

    private func analyze(windows: [AppWindowInfo]) async {
        let frontmost = windows.first(where: { $0.isOnTop })
        let activeApps = Set(windows.map(\.bundleID))
        let timeOfDay = TimeOfDay.current()

        let calendarEvents = hasCalendarAccess ? fetchCurrentCalendarEvents() : []
        let focusMode = getCurrentFocusMode()

        let deepContexts = await extractDeepContexts(from: windows)
        let frontmostDeep = frontmost.flatMap { fw in
            deepContexts[fw.bundleID]
        }

        let productivity = estimateProductivity(
            apps: Array(activeApps),
            timeOfDay: timeOfDay,
            calendarEvents: calendarEvents,
            focusMode: focusMode,
            deepContexts: deepContexts
        )

        let suggestedMode = suggestSpaceMode(
            apps: Array(activeApps),
            frontmostApp: frontmost?.bundleID ?? "",
            timeOfDay: timeOfDay,
            calendarEvents: calendarEvents,
            deepContexts: deepContexts
        )

        let allURLs = deepContexts.values.flatMap(\.urls).unique()
        let allTabs = deepContexts.values.flatMap(\.tabs).unique()

        let context = DetectedContext(
            activeApps: Array(activeApps).sorted(),
            frontmostApp: frontmost?.bundleID ?? "",
            frontmostWindowTitle: frontmost?.windowTitle ?? "",
            activeURLs: allURLs.isEmpty ? (frontmost?.tabs ?? allTabs) : allURLs,
            timeOfDay: timeOfDay,
            focusMode: focusMode,
            calendarEvents: calendarEvents,
            productivityEstimate: productivity,
            suggestedSpaceMode: suggestedMode,
            confidence: calculateConfidence(productivity, suggestedMode, deepContexts),
            appDeepContexts: deepContexts,
            activeWindowUI: frontmostDeep?.uiTree
        )

        lastDetectedContext = context
        contextContinuation.yield(context)
    }

    private func extractDeepContexts(from windows: [AppWindowInfo]) async -> [String: AppDeepContext] {
        let frontmostBundle = windows.first(where: { $0.isOnTop })?.bundleID
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        return await withTaskGroup(of: [String: AppDeepContext].self) { group in
            var count = 0
            for app in apps {
                guard count < 3, let bundleID = app.bundleIdentifier else { continue }
                let isPriority = bundleID == frontmostBundle
                if !isPriority, count >= 3 { break }
                count += 1
                group.addTask {
                    let deep = await MainActor.run { AXUIHelper.getDeepAppContext(for: app) }
                    if let deep { return [bundleID: deep] }
                    return [:]
                }
            }

            var collected: [String: AppDeepContext] = [:]
            for await dict in group {
                collected.merge(dict) { $1 }
            }
            return collected
        }
    }

    private func fetchCurrentCalendarEvents() -> [CalendarEvent] {
        let eventStore = EKEventStore()
        let calendar = Calendar.current
        let now = Date()
        guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { $0.startDate <= now && $0.endDate >= now }

        return events.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar.title
            )
        }
    }

    private func getCurrentFocusMode() -> String? {
        UserDefaults.standard.string(forKey: "focusMode")
    }

    private func estimateProductivity(
        apps: [String],
        timeOfDay: TimeOfDay,
        calendarEvents: [CalendarEvent],
        focusMode: String?,
        deepContexts: [String: AppDeepContext] = [:]
    ) -> ProductivityLevel {
        let distractionApps = [
            "com.apple.TV", "com.netflix.Netflix", "com.spotify.client",
            "com.apple.gamecenter", "com.apple.PhotoBooth"
        ]
        let productivityApps = [
            "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.apple.TextEdit",
            "com.apple.Safari", "com.microsoft.Excel", "com.apple.Pages"
        ]

        // Deep context analysis: check what the user is actually doing
        for (_, deep) in deepContexts {
            if let state = deep.uiState {
                if state == "debugging" { return .focused }
                if state == "terminal" { return .focused }
            }
            if let _ = deep.activeFile { return .focused }
            if let focused = deep.focusedElement {
                let codeRoles = ["AXTextField", "AXTextArea", "AXSourceEditor"]
                if codeRoles.contains(focused.role) { return .focused }
            }
        }

        let hasDistraction = apps.contains { distractionApps.contains($0) }
        let hasProductivity = apps.contains { productivityApps.contains($0) }
        let hasMeeting = !calendarEvents.isEmpty

        if focusMode == "Focus" || focusMode == "Work" {
            return hasDistraction ? .neutral : .focused
        }
        if hasMeeting { return .focused }
        if hasProductivity && !hasDistraction { return .focused }
        if hasDistraction { return .distracted }
        if timeOfDay == .night || timeOfDay == .earlyMorning { return .idle }
        return .neutral
    }

    private func suggestSpaceMode(
        apps: [String],
        frontmostApp: String,
        timeOfDay: TimeOfDay,
        calendarEvents: [CalendarEvent],
        deepContexts: [String: AppDeepContext] = [:]
    ) -> SpaceMode? {
        if !calendarEvents.isEmpty { return .meetings }

        // Deep context: detect actual activity from UI state
        for (_, deep) in deepContexts {
            if let state = deep.uiState {
                if state == "debugging" { return .coding }
            }
            if let _ = deep.activeFile { return .coding }
            if let focused = deep.focusedElement {
                if focused.role == "AXTextArea" || focused.role == "AXSourceEditor" { return .coding }
                if focused.role == "AXWebArea" { return .browsing }
            }
            if !deep.tabs.isEmpty { return .browsing }
            if !deep.urls.isEmpty { return .browsing }
        }

        let codeApps = ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.jetbrains.intellij", "com.apple.Terminal"]
        let creativeApps = ["com.apple.finalcutpro", "com.seriflabs.affinityphoto2", "com.adobe.illustrator", "com.apple.garageband10"]
        let browsingApps = ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"]

        if apps.contains(where: { codeApps.contains($0) }) { return .coding }
        if apps.contains(where: { creativeApps.contains($0) }) { return .creative }
        if apps.contains(where: { browsingApps.contains($0) }) { return .browsing }

        if timeOfDay == .morning || timeOfDay == .afternoon {
            if apps.count <= 2 && apps.count > 0 { return .deepWork }
        }

        return nil
    }

    private func calculateConfidence(_ productivity: ProductivityLevel, _ mode: SpaceMode?, _ deepContexts: [String: AppDeepContext] = [:]) -> Double {
        var confidence = 0.5
        if productivity == .focused { confidence += 0.2 }
        if mode != nil { confidence += 0.2 }
        if !deepContexts.isEmpty { confidence += 0.15 }
        if deepContexts.values.contains(where: { $0.focusedElement != nil }) { confidence += 0.1 }
        if deepContexts.values.contains(where: { $0.activeFile != nil }) { confidence += 0.1 }
        return min(confidence, 1.0)
    }

    public func getLastContext() -> DetectedContext? {
        lastDetectedContext
    }
}
