import Foundation
import AppKit

public enum EmailTrackerEvent: Sendable {
    case sessionStarted(EmailSession)
    case sessionEnded(EmailSession, ActivityRecord)
    case deadlineDetected(subject: String, date: Date)
    case error(Error)
}

public struct EmailSession: Sendable, Equatable {
    public var id: String
    public var senderName: String?
    public var senderEmail: String?
    public var subject: String?
    public var bodySnippet: String?
    public var isCompose: Bool
    public var platform: String
    public var startTime: Date
    public var endTime: Date?
    public var messageCount: Int

    public var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
    }

    public init(id: String = UUID().uuidString, senderName: String? = nil, senderEmail: String? = nil,
                subject: String? = nil, bodySnippet: String? = nil, isCompose: Bool = false,
                platform: String, startTime: Date = Date(), endTime: Date? = nil, messageCount: Int = 1) {
        self.id = id
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.subject = subject
        self.bodySnippet = bodySnippet
        self.isCompose = isCompose
        self.platform = platform
        self.startTime = startTime
        self.endTime = endTime
        self.messageCount = messageCount
    }
}

public actor EmailTracker {
    public static let shared = EmailTracker()

    private var activeSession: EmailSession?
    private var monitoringTask: Task<Void, Never>?
    private let stream = AsyncStream<EmailTrackerEvent>.makeStream()
    private var isEnabled = false
    private let extractor = BrowserExtractor()

    public var events: AsyncStream<EmailTrackerEvent> {
        stream.stream
    }

    public var currentSession: EmailSession? {
        activeSession
    }

    private static let emailURLPatterns: [(host: String, label: String)] = [
        ("mail.google.com", "Gmail"),
        ("mail.google.com/a/", "Gmail Workspace"),
        ("outlook.live.com", "Outlook"),
        ("outlook.office.com", "Outlook"),
        ("outlook.office365.com", "Outlook"),
        ("mail.yahoo.com", "Yahoo Mail"),
        ("mail.proton.me", "ProtonMail"),
        ("fastmail.com", "Fastmail"),
        ("mail.aol.com", "AOL Mail"),
        ("mail.zoho.com", "Zoho Mail"),
    ]

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
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    // MARK: - App Detection

    private func checkFrontmostApp() async {
        guard isEnabled else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else {
            endCurrentSession()
            return
        }

        if bundleID == "com.apple.mail" {
            await checkAppleMail()
        } else if let browser = BrowserType.from(bundleID: bundleID) {
            await checkBrowserEmail(browser: browser)
        } else {
            endCurrentSession()
        }
    }

    // MARK: - Apple Mail

    private func checkAppleMail() async {
        guard let mailInfo = await extractMailMessage() else {
            endCurrentSession()
            return
        }

        let bodyLevel = emailBodyCaptureLevel()
        let snippet: String?
        if bodyLevel == .preview {
            snippet = mailInfo.body?.isEmpty == false ? String(mailInfo.body!.prefix(200)) : nil
        } else if bodyLevel == .full {
            snippet = mailInfo.body
        } else {
            snippet = nil
        }

        if var session = activeSession {
            guard session.subject == mailInfo.subject && session.senderEmail == mailInfo.senderEmail else {
                endCurrentSession()
                startNewSession(mailInfo: mailInfo, snippet: snippet)
                return
            }
            session.endTime = Date()
            session.messageCount += 1
            activeSession = session
        } else {
            startNewSession(mailInfo: mailInfo, snippet: snippet)
        }
    }

    private func extractMailMessage() async -> (senderName: String?, senderEmail: String?, subject: String?, body: String?)? {
        let subjectScript = """
        tell application "Mail"
            set selectedMessages to selection
            if selectedMessages is {} then return ""
            set msg to item 1 of selectedMessages
            set msgSubject to subject of msg
            set msgSender to sender of msg
            set msgBody to content of msg
            return msgSender & "|||" & msgSubject & "|||" & msgBody
        end tell
        """

        guard let result = await runAppleScript(subjectScript) else { return nil }
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }

        let sender = parts[0].isEmpty ? nil : parts[0]
        let subject = parts.count >= 2 ? (parts[1].isEmpty ? nil : parts[1]) : nil
        let body = parts.count >= 3 ? (parts[2].isEmpty ? nil : parts[2]) : nil

        let senderParts = sender?.components(separatedBy: " <")
        let senderName = senderParts?.first
        let senderEmail = senderParts?.last?.trimmingCharacters(in: CharacterSet(charactersIn: "> "))

        return (senderName, senderEmail, subject, body)
    }

    // MARK: - Browser Email

    private func checkBrowserEmail(browser: BrowserType) async {
        guard let page = await extractor.extractFrontPage(for: browser.rawValue) else {
            endCurrentSession()
            return
        }

        guard let matchedEmail = matchEmailURL(page.url) else {
            endCurrentSession()
            return
        }

        if var session = activeSession {
            guard session.subject == page.title && session.platform == matchedEmail else {
                endCurrentSession()
                startNewSession(platform: matchedEmail, page: page)
                return
            }
            session.endTime = Date()
            session.messageCount += 1
            activeSession = session
        } else {
            startNewSession(platform: matchedEmail, page: page)
        }
    }

    private func matchEmailURL(_ url: String) -> String? {
        guard let components = URLComponents(string: url),
              let host = components.host else { return nil }
        let hostLower = host.lowercased()
        for (pattern, label) in EmailTracker.emailURLPatterns {
            if hostLower.contains(pattern) { return label }
        }
        return nil
    }

    // MARK: - Session Management

    private func startNewSession(mailInfo: (senderName: String?, senderEmail: String?, subject: String?, body: String?), snippet: String?) {
        let session = EmailSession(
            senderName: mailInfo.senderName,
            senderEmail: mailInfo.senderEmail,
            subject: mailInfo.subject,
            bodySnippet: snippet,
            isCompose: false,
            platform: "Apple Mail"
        )
        activeSession = session
        stream.continuation.yield(.sessionStarted(session))

        if let subject = mailInfo.subject {
            checkForDeadline(subject: subject, body: mailInfo.body)
        }
    }

    private func startNewSession(platform: String, page: BrowserPage) {
        let session = EmailSession(
            subject: page.title,
            platform: platform
        )
        activeSession = session
        stream.continuation.yield(.sessionStarted(session))
    }

    private func endCurrentSession() {
        guard let session = activeSession else { return }
        let ended = EmailSession(
            id: session.id, senderName: session.senderName, senderEmail: session.senderEmail,
            subject: session.subject, bodySnippet: session.bodySnippet,
            isCompose: session.isCompose, platform: session.platform,
            startTime: session.startTime, endTime: Date(),
            messageCount: session.messageCount
        )
        activeSession = nil

        guard ended.duration >= 5 else { return }

        let meta = EmailMetadata(
            sender: ended.senderName,
            senderEmail: ended.senderEmail,
            subject: ended.subject,
            isThread: ended.messageCount > 3,
            messageCount: ended.messageCount
        )
        let metaJSON = (try? JSONEncoder().encode(meta)).flatMap { String(data: $0, encoding: .utf8) }

        let record = ActivityRecord(
            activityType: .email,
            category: "email",
            appBundleID: "com.apple.mail",
            appName: "Mail",
            title: ended.subject,
            contentExcerpt: ended.bodySnippet,
            metadataJSON: metaJSON,
            duration: ended.duration,
            confidence: 0.8,
            source: "email_tracker",
            sessionID: ended.id
        )

        Task { @MainActor in
            await ActivityTracker.shared.insert(record)
        }

        stream.continuation.yield(.sessionEnded(ended, record))
    }

    // MARK: - Deadline Detection

    private func checkForDeadline(subject: String, body: String?) {
        let deadlinePatterns = [
            "deadline", "due date", "due by", "due on", "due:", "by eod",
            "by end of day", "by tomorrow", "by friday", "by monday",
            "urgent", "asap", "action required", "response needed",
        ]
        let searchText = "\(subject) \(body ?? "")".lowercased()
        let hasDeadlineKeyword = deadlinePatterns.contains { searchText.contains($0) }
        guard hasDeadlineKeyword else { return }

        if let detectedDate = extractDate(from: searchText) {
            stream.continuation.yield(.deadlineDetected(subject: subject, date: detectedDate))
        }
    }

    private func extractDate(from text: String) -> Date? {
        let patterns = [
            "by (\\d{1,2}/\\d{1,2}(?:/\\d{2,4})?)": "MM/dd/yyyy",
            "due (\\d{1,2}/\\d{1,2}(?:/\\d{2,4})?)": "MM/dd/yyyy",
            "by (\\d{4}-\\d{2}-\\d{2})": "yyyy-MM-dd",
            "due (\\d{4}-\\d{2}-\\d{2})": "yyyy-MM-dd",
        ]

        for (pattern, format) in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let dateStr = String(text[match])
                    .replacingOccurrences(of: "by ", with: "")
                    .replacingOccurrences(of: "due ", with: "")
                let formatter = DateFormatter()
                formatter.dateFormat = format
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func runAppleScript(_ source: String) async -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return output.stringValue
    }

    private func emailBodyCaptureLevel() -> PrivacySettings.ContentCaptureLevel {
        let raw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.trackEmailBody)
        return raw.flatMap(PrivacySettings.ContentCaptureLevel.init(rawValue:)) ?? .preview
    }
}
