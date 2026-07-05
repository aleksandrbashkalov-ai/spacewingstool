import Foundation
import Observation
import AppKit

public enum ReadingTrackerEvent: Sendable {
    case sessionStarted(ReadingSession)
    case sessionEnded(ReadingSession, ActivityRecord)
    case contentExtracted(url: String, title: String)
    case error(Error)
}

public struct ReadingSession: Sendable, Equatable {
    public var id: String
    public var url: String
    public var title: String
    public var browser: String
    public var startTime: Date
    public var endTime: Date?
    public var wordsRead: Int
    public var scrollDepth: Double
    public var isPDF: Bool

    public var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
    }

    public init(id: String = UUID().uuidString, url: String, title: String, browser: String,
                startTime: Date = Date(), endTime: Date? = nil, wordsRead: Int = 0,
                scrollDepth: Double = 0, isPDF: Bool = false) {
        self.id = id
        self.url = url
        self.title = title
        self.browser = browser
        self.startTime = startTime
        self.endTime = endTime
        self.wordsRead = wordsRead
        self.scrollDepth = scrollDepth
        self.isPDF = isPDF
    }
}

public actor ReadingTracker {
    public static let shared = ReadingTracker()

    private let extractor = BrowserExtractor()
    private var activeSession: ReadingSession?
    private var monitoringTask: Task<Void, Never>?
    private let stream = AsyncStream<ReadingTrackerEvent>.makeStream()
    private let sessionDebounceInterval: TimeInterval = 30
    private let minimumReadingDuration: TimeInterval = 15
    private var isEnabled = false

    public var events: AsyncStream<ReadingTrackerEvent> {
        stream.stream
    }

    public var currentSession: ReadingSession? {
        activeSession
    }

    private init() {}

    // MARK: - Lifecycle

    public func start() {
        guard !isEnabled else { return }
        isEnabled = true
        startMonitoring()
    }

    public func stop() {
        isEnabled = false
        monitoringTask?.cancel()
        monitoringTask = nil
        endCurrentSession()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkFrontmostApp()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private func checkFrontmostApp() async {
        guard isEnabled else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else {
            endCurrentSession()
            return
        }

        guard BrowserType.from(bundleID: bundleID) != nil || isPDFViewer(bundleID) else {
            endCurrentSession()
            return
        }

        let contentLevel = readingContentCaptureLevel()
        guard contentLevel != .off else { return }

        var page = await extractor.extractFrontPage(for: bundleID)
        if contentLevel == .preview, let text = page?.textContent {
            page = BrowserPage(url: page!.url, title: page!.title,
                               textContent: String(text.prefix(500)), browser: page!.browser)
        }

        if let page {
            stream.continuation.yield(.contentExtracted(url: page.url, title: page.title))
            updateSession(with: page)
        }
    }

    private func readingContentCaptureLevel() -> PrivacySettings.ContentCaptureLevel {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.trackReadingContent)
        return raw.flatMap(PrivacySettings.ContentCaptureLevel.init(rawValue:)) ?? .preview
    }

    // MARK: - Session Management

    private func updateSession(with page: BrowserPage) {
        if var session = activeSession {
            guard page.url != session.url || page.browser != session.browser else {
                session.endTime = Date()
                activeSession = session
                return
            }
            endCurrentSession()
            startNewSession(with: page)
        } else {
            startNewSession(with: page)
        }
    }

    private func startNewSession(with page: BrowserPage) {
        guard page.url != "about:blank" && !page.url.isEmpty else { return }
        let session = ReadingSession(
            url: page.url,
            title: page.title,
            browser: page.browser,
            isPDF: page.url.hasSuffix(".pdf") || page.title.contains("PDF")
        )
        activeSession = session
        stream.continuation.yield(.sessionStarted(session))
    }

    private func endCurrentSession() {
        guard let session = activeSession else { return }
        let ended = ReadingSession(
            id: session.id, url: session.url, title: session.title,
            browser: session.browser, startTime: session.startTime,
            endTime: Date(), wordsRead: session.wordsRead,
            scrollDepth: session.scrollDepth, isPDF: session.isPDF
        )
        activeSession = nil

        guard ended.duration >= minimumReadingDuration else { return }

        let record = ActivityRecord(
            activityType: .reading,
            category: ended.isPDF ? "pdf" : "web",
            appBundleID: browserBundleID(ended.browser),
            appName: ended.browser,
            title: ended.title,
            contentExcerpt: nil,
            metadataJSON: encodeMetadata(ended),
            duration: ended.duration,
            confidence: 0.8,
            source: "reading_tracker",
            sessionID: ended.id
        )

        Task { @MainActor in
            await ActivityTracker.shared.insert(record)
        }

        stream.continuation.yield(.sessionEnded(ended, record))
    }

    public func forceEndSession() {
        endCurrentSession()
    }

    // MARK: - PDF Detection

    private func isPDFViewer(_ bundleID: String) -> Bool {
        let pdfViewers: Set<String> = [
            "com.apple.Preview",
            "com.apple.iBooksX",
            "com.readdle.PDFExpert-Mac",
            "com.google.Chrome",
            "com.apple.Safari",
            "com.brave.Browser",
            "com.microsoft.Edge",
        ]
        return pdfViewers.contains(bundleID)
    }

    // MARK: - Helpers

    private func browserBundleID(_ name: String) -> String? {
        switch name {
        case "Safari": return "com.apple.Safari"
        case "Chrome": return "com.google.Chrome"
        case "Brave": return "com.brave.Browser"
        case "Microsoft Edge": return "com.microsoft.Edge"
        case "Firefox": return "org.mozilla.firefox"
        case "Arc": return "company.thebrowser.Browser"
        case "Orion": return "com.kagi.kagimacOS"
        default: return nil
        }
    }

    private func encodeMetadata(_ session: ReadingSession) -> String? {
        let meta = ReadingMetadata(
            url: session.url,
            estimatedWords: session.wordsRead > 0 ? session.wordsRead : nil,
            scrollDepth: session.scrollDepth > 0 ? session.scrollDepth : nil
        )
        guard let data = try? JSONEncoder().encode(meta) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
