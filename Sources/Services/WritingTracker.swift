import Foundation
import AppKit

public enum WritingTrackerEvent: Sendable {
    case sessionStarted(EditingSession)
    case sessionEnded(EditingSession, ActivityRecord)
    case keystrokeRecorded(count: Int, wpm: Double)
    case error(Error)
}

public struct EditingSession: Sendable, Equatable {
    public var id: String
    public var documentName: String?
    public var documentPath: String?
    public var appName: String
    public var appBundleID: String
    public var startTime: Date
    public var endTime: Date?
    public var keystrokeCount: Int
    public var activeWritingTime: TimeInterval
    public var averageWPM: Double

    public var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
    }

    public init(id: String = UUID().uuidString, documentName: String? = nil, documentPath: String? = nil,
                appName: String, appBundleID: String, startTime: Date = Date(), endTime: Date? = nil,
                keystrokeCount: Int = 0, activeWritingTime: TimeInterval = 0, averageWPM: Double = 0) {
        self.id = id
        self.documentName = documentName
        self.documentPath = documentPath
        self.appName = appName
        self.appBundleID = appBundleID
        self.startTime = startTime
        self.endTime = endTime
        self.keystrokeCount = keystrokeCount
        self.activeWritingTime = activeWritingTime
        self.averageWPM = averageWPM
    }
}

public actor WritingTracker {
    public static let shared = WritingTracker()

    private static let writingApps: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.apple.TextEdit",
        "com.apple.Pages",
        "com.apple.Notes",
        "com.ulyssesapp.ios",
        "com.tinynudge.pomello",
        "com.barebones.bbedit",
        "com.macvim.MacVim",
        "org.vim.MacVim",
        "com.neovide.neovide",
        "com.microsoft.Word",
        "com.apple.Keynote",
        "com.apple.iWork.Pages",
        "co.noteplan.NotePlan",
        "com.mediaatelier.Dash",
    ]

    private static let writingAppPrefixes: [String] = [
        "com.jetbrains",
        "com.sublimetext",
    ]

    private var activeSession: EditingSession?
    private var monitoringTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var eventMonitor: Any?
    private let stream = AsyncStream<WritingTrackerEvent>.makeStream()
    private var isEnabled = false
    private let idleTimeout: TimeInterval = 120

    public var events: AsyncStream<WritingTrackerEvent> {
        stream.stream
    }

    public var currentSession: EditingSession? {
        activeSession
    }

    private init() {}

    // MARK: - Lifecycle

    public func start() {
        guard !isEnabled else { return }
        isEnabled = true
        startMonitoring()
        startKeystrokeCounting()
    }

    public func stop() {
        isEnabled = false
        monitoringTask?.cancel()
        monitoringTask = nil
        idleTask?.cancel()
        idleTask = nil
        removeKeystrokeMonitor()
        endCurrentSession()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkFrontmostApp()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func startKeystrokeCounting() {
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            Task { [weak self] in
                await self?.recordKeystroke()
            }
        }
        eventMonitor = monitor
    }

    private func removeKeystrokeMonitor() {
        if let monitor = eventMonitor as? NSObjectProtocol {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitor = nil
    }

    // MARK: - Writing Detection

    private func checkFrontmostApp() {
        guard isEnabled else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              let appName = app.localizedName else {
            endCurrentSession()
            return
        }

        guard isWritingApp(bundleID) else {
            endCurrentSession()
            return
        }

        let docInfo = extractDocumentInfo(app: app, bundleID: bundleID)

        if var session = activeSession {
            guard docInfo.name == session.documentName && bundleID == session.appBundleID else {
                endCurrentSession()
                startNewSession(appName: appName, bundleID: bundleID, documentName: docInfo.name, documentPath: docInfo.path)
                return
            }
            session.endTime = Date()
            activeSession = session
        } else {
            startNewSession(appName: appName, bundleID: bundleID, documentName: docInfo.name, documentPath: docInfo.path)
        }
    }

    private func startNewSession(appName: String, bundleID: String, documentName: String?, documentPath: String?) {
        let captureLevel = writingContentCaptureLevel()
        let name = captureLevel == .off ? nil : documentName
        let path = captureLevel == .metadataOnly ? nil : documentPath

        let session = EditingSession(
            documentName: name,
            documentPath: path,
            appName: appName,
            appBundleID: bundleID
        )
        activeSession = session
        stream.continuation.yield(.sessionStarted(session))
    }

    private func endCurrentSession() {
        guard var session = activeSession else { return }
        session.endTime = Date()
        activeSession = nil

        guard session.duration >= 10 else { return }

        let wpm: Double
        if session.activeWritingTime > 0 && session.keystrokeCount > 0 {
            let minutes = session.activeWritingTime / 60
            let adjusted = max((Double(session.keystrokeCount) / 5 - 200), 0)
            wpm = minutes > 0 ? adjusted / minutes : 0
        } else {
            wpm = 0
        }
        session.averageWPM = wpm

        let meta = WritingMetadata(
            documentName: session.documentName,
            wordCount: nil,
            keystrokeCount: session.keystrokeCount,
            activeWritingTime: session.activeWritingTime,
            documentPath: session.documentPath,
            appBundleID: session.appBundleID
        )
        let metaJSON = (try? JSONEncoder().encode(meta)).flatMap { String(data: $0, encoding: .utf8) }

        let record = ActivityRecord(
            activityType: .writing,
            category: "writing",
            appBundleID: session.appBundleID,
            appName: session.appName,
            title: session.documentName,
            contentExcerpt: nil,
            metadataJSON: metaJSON,
            duration: session.duration,
            confidence: 0.7,
            source: "writing_tracker",
            sessionID: session.id
        )

        Task { @MainActor in
            await ActivityTracker.shared.insert(record)
        }

        stream.continuation.yield(.sessionEnded(session, record))
    }

    // MARK: - Keystroke Tracking

    private func recordKeystroke() {
        guard var session = activeSession else { return }
        session.keystrokeCount += 1
        session.activeWritingTime += 0.1
        activeSession = session

        resetIdleTimer()

        if session.activeWritingTime.truncatingRemainder(dividingBy: 60) < 0.2 {
            let minutes = session.activeWritingTime / 60
            let adjusted = max((Double(session.keystrokeCount) / 5 - 200), 0)
            let wpm = minutes > 0 ? adjusted / minutes : 0
            stream.continuation.yield(.keystrokeRecorded(count: session.keystrokeCount, wpm: wpm))
        }
    }

    private func resetIdleTimer() {
        idleTask?.cancel()
        let timeout = self.idleTimeout
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            await self?.endCurrentSession()
        }
    }

    // MARK: - AX Document Info

    private func extractDocumentInfo(app: NSRunningApplication, bundleID: String) -> (name: String?, path: String?) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &focusedWindow) == .success,
              let window = focusedWindow else {
            return (extractFromBundleID(app, bundleID), nil)
        }

        let windowElement = window as! AXUIElement
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement, "AXTitle" as CFString, &title)

        var document: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement, "AXDocument" as CFString, &document)

        let titleStr = title.flatMap { $0 as? String }
        let docStr = document.flatMap { $0 as? String }

        if let docStr, !docStr.isEmpty {
            let url = URL(fileURLWithPath: docStr)
            return (url.lastPathComponent, docStr)
        }

        if let titleStr, !titleStr.isEmpty {
            return cleanDocumentName(titleStr, bundleID: bundleID)
        }

        return (extractFromBundleID(app, bundleID), nil)
    }

    private func cleanDocumentName(_ title: String, bundleID: String) -> (name: String?, path: String?) {
        if bundleID == "com.microsoft.VSCode" || bundleID.hasPrefix("com.microsoft.VSCode") {
            let parts = title.components(separatedBy: " — ")
            return (parts.first, nil)
        }
        if bundleID == "com.apple.dt.Xcode" {
            let parts = title.components(separatedBy: " — ")
            return (parts.first, nil)
        }
        if bundleID.hasPrefix("com.jetbrains") {
            let parts = title.components(separatedBy: " – ")
            return (parts.first, nil)
        }
        return (title, nil)
    }

    private func extractFromBundleID(_ app: NSRunningApplication, _ bundleID: String) -> String? {
        app.localizedName
    }

    // MARK: - Helpers

    private func isWritingApp(_ bundleID: String) -> Bool {
        if WritingTracker.writingApps.contains(bundleID) { return true }
        for prefix in WritingTracker.writingAppPrefixes {
            if bundleID.hasPrefix(prefix) { return true }
        }
        return false
    }

    private func writingContentCaptureLevel() -> PrivacySettings.WritingContentCapture {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.trackWritingContent)
        return raw.flatMap(PrivacySettings.WritingContentCapture.init(rawValue:)) ?? .metadataOnly
    }
}
