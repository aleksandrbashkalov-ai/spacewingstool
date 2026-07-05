import Foundation
import AppKit
import Speech
import AVFoundation

public enum MeetingTrackerEvent: Sendable {
    case meetingStarted(MeetingSession)
    case meetingEnded(MeetingSession, ActivityRecord)
    case participantsChanged(count: Int, names: [String])
    case transcriptionAvailable(sessionID: String, text: String)
    case error(Error)
}

public struct MeetingSession: Sendable, Equatable {
    public var id: String
    public var platform: String
    public var meetingTitle: String?
    public var participantCount: Int
    public var participantNames: [String]
    public var isPresenting: Bool
    public var isScreenSharing: Bool
    public var startTime: Date
    public var endTime: Date?
    public var hasTranscription: Bool

    public var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? Date().timeIntervalSince(startTime)
    }

    public init(id: String = UUID().uuidString, platform: String, meetingTitle: String? = nil,
                participantCount: Int = 0, participantNames: [String] = [],
                isPresenting: Bool = false, isScreenSharing: Bool = false,
                startTime: Date = Date(), endTime: Date? = nil, hasTranscription: Bool = false) {
        self.id = id
        self.platform = platform
        self.meetingTitle = meetingTitle
        self.participantCount = participantCount
        self.participantNames = participantNames
        self.isPresenting = isPresenting
        self.isScreenSharing = isScreenSharing
        self.startTime = startTime
        self.endTime = endTime
        self.hasTranscription = hasTranscription
    }
}

public actor MeetingTracker {
    public static let shared = MeetingTracker()

    private var activeSession: MeetingSession?
    private var monitoringTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private let stream = AsyncStream<MeetingTrackerEvent>.makeStream()
    private var isEnabled = false
    private let extractor = BrowserExtractor()

    public var events: AsyncStream<MeetingTrackerEvent> {
        stream.stream
    }

    public var currentSession: MeetingSession? { activeSession }

    private static let meetingAppBundleIDs: Set<String> = [
        "us.zoom.xos",
        "us.zoom.ZoomChat",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.tinyspeck.slackmacos",
        "com.hnc.Discord",
        "com.cisco.webex",
        "com.cisco.webex.meetings",
        "com.logmein.gotomeeting",
        "com.logmein.gotowebinar",
        "com.uberconference.air",
        "com.bluejeans.bluejeans",
        "com.whereby.browser",
    ]

    private static let meetingURLPatterns: [(pattern: String, platform: String)] = [
        ("meet.google.com", "Google Meet"),
        ("teams.microsoft.com/meeting", "Microsoft Teams"),
        ("teams.microsoft.com/l/meetup-join", "Microsoft Teams"),
        ("zoom.us/j/", "Zoom"),
        ("zoom.us/wc/", "Zoom"),
        ("zoom.us/s/", "Zoom"),
        ("webex.com/meet", "WebEx"),
        ("go-to.me/", "GoToMeeting"),
        ("gotomeeting.com/join", "GoToMeeting"),
        ("whereby.com", "Whereby"),
        ("bluejeans.com", "BlueJeans"),
        ("uberconference.com", "UberConference"),
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
        transcriptionTask?.cancel()
        transcriptionTask = nil
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

    // MARK: - Detection

    private func checkFrontmostApp() async {
        guard isEnabled else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else {
            endCurrentSession()
            return
        }

        if isMeetingApp(bundleID) {
            await handleMeetingApp(app: app, bundleID: bundleID)
        } else if let browser = BrowserType.from(bundleID: bundleID) {
            await checkBrowserMeeting(browser: browser)
        } else {
            endCurrentSession()
        }
    }

    private func isMeetingApp(_ bundleID: String) -> Bool {
        MeetingTracker.meetingAppBundleIDs.contains(bundleID)
    }

    // MARK: - Native Meeting Apps

    private func handleMeetingApp(app: NSRunningApplication, bundleID: String) async {
        let platform = platformName(bundleID)
        let title = extractMeetingTitle(app: app, bundleID: bundleID)

        let participants = extractParticipants(app: app, bundleID: bundleID)
        let isPresenting = checkPresenting(app: app, bundleID: bundleID)
        let isSharing = checkScreenSharing(app: app, bundleID: bundleID)

        if var session = activeSession {
            guard session.platform == platform && session.meetingTitle == title else {
                endCurrentSession()
                startNewSession(platform: platform, title: title, participants: participants,
                                isPresenting: isPresenting, isSharing: isSharing)
                return
            }
            session.endTime = Date()
            if session.participantCount != participants.count {
                stream.continuation.yield(.participantsChanged(count: participants.count, names: participants))
            }
            session.participantCount = max(session.participantCount, participants.count)
            activeSession = session
        } else {
            startNewSession(platform: platform, title: title, participants: participants,
                            isPresenting: isPresenting, isSharing: isSharing)
        }
    }

    private func platformName(_ bundleID: String) -> String {
        switch bundleID {
        case "us.zoom.xos", "us.zoom.ZoomChat": return "Zoom"
        case "com.microsoft.teams", "com.microsoft.teams2": return "Microsoft Teams"
        case "com.apple.FaceTime": return "FaceTime"
        case "com.tinyspeck.slackmacos": return "Slack"
        case "com.hnc.Discord": return "Discord"
        case "com.cisco.webex", "com.cisco.webex.meetings": return "WebEx"
        case "com.logmein.gotomeeting": return "GoToMeeting"
        default: return bundleID
        }
    }

    // MARK: - Browser Meetings

    private func checkBrowserMeeting(browser: BrowserType) async {
        guard let page = await extractor.extractFrontPage(for: browser.rawValue) else {
            endCurrentSession()
            return
        }

        guard let matched = matchMeetingURL(page.url) else {
            endCurrentSession()
            return
        }

        if var session = activeSession {
            guard session.meetingTitle == page.title && session.platform == matched.platform else {
                endCurrentSession()
                startNewSession(platform: matched.platform, title: page.title, participants: [])
                return
            }
            session.endTime = Date()
            activeSession = session
        } else {
            startNewSession(platform: matched.platform, title: page.title, participants: [])
        }
    }

    private func matchMeetingURL(_ url: String) -> (platform: String, title: String?)? {
        let lower = url.lowercased()
        for (pattern, platform) in MeetingTracker.meetingURLPatterns {
            if lower.contains(pattern) {
                return (platform, extractMeetingTitleFromURL(url))
            }
        }
        return nil
    }

    private func extractMeetingTitleFromURL(_ url: String) -> String? {
        guard let components = URLComponents(string: url),
              let queryItems = components.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "title" })?.value
    }

    // MARK: - AX Participant Detection

    private func extractParticipants(app: NSRunningApplication, bundleID: String) -> [String] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        if bundleID == "us.zoom.xos" || bundleID == "us.zoom.ZoomChat" {
            return extractZoomParticipants(appElement: appElement)
        }
        if bundleID == "com.microsoft.teams" || bundleID == "com.microsoft.teams2" {
            return extractTeamsParticipants(appElement: appElement)
        }

        return []
    }

    private func extractZoomParticipants(appElement: AXUIElement) -> [String] {
        var names: [String] = []

        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXWindows" as CFString, &windows) == .success,
              let windowList = windows as? [AXUIElement] else { return [] }

        for window in windowList {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(window, "AXTitle" as CFString, &title)
            if let titleStr = title as? String {
                if let count = extractParticipantCount(from: titleStr) {
                    for _ in 0..<min(count, 1) { names.append("") }
                    break
                }
            }
        }
        return names
    }

    private func extractTeamsParticipants(appElement: AXUIElement) -> [String] {
        var names: [String] = []
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXWindows" as CFString, &windows) == .success,
              let windowList = windows as? [AXUIElement] else { return [] }

        for window in windowList {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(window, "AXTitle" as CFString, &title)
            if let titleStr = title as? String {
                if let count = extractParticipantCount(from: titleStr) {
                    for _ in 0..<min(count, 1) { names.append("") }
                    break
                }
            }
        }
        return names
    }

    private func extractParticipantCount(from title: String) -> Int? {
        let patterns = [
            "\\((\\d+)\\)",
            "(\\d+) participants",
            "(\\d+) attendees",
        ]
        for pattern in patterns {
            if let range = title.range(of: pattern, options: .regularExpression) {
                let match = title[range]
                let digits = match.filter { $0.isNumber }
                if let count = Int(digits), count > 0 { return count }
            }
        }
        return nil
    }

    // MARK: - Presenting / Screen Sharing Detection

    private func checkPresenting(app: NSRunningApplication, bundleID: String) -> Bool {
        if bundleID == "us.zoom.xos" || bundleID == "us.zoom.ZoomChat" {
            return checkZoomPresenting(app: app)
        }
        if bundleID == "com.microsoft.teams" || bundleID == "com.microsoft.teams2" {
            return checkTeamsPresenting(app: app)
        }
        return false
    }

    private func checkScreenSharing(app: NSRunningApplication, bundleID: String) -> Bool {
        _ = app
        if bundleID == "us.zoom.xos" || bundleID == "us.zoom.ZoomChat" {
            return true
        }
        return false
    }

    private func checkZoomPresenting(app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return false }
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, "AXTitle" as CFString, &title)
        return (title as? String)?.contains("Presenting") == true
    }

    private func checkTeamsPresenting(app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return false }
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, "AXTitle" as CFString, &title)
        return (title as? String)?.contains("Presenting") == true
    }

    // MARK: - Meeting Title

    private func extractMeetingTitle(app: NSRunningApplication, bundleID: String) -> String? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return nil }
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, "AXTitle" as CFString, &title)
        guard let titleStr = title as? String, !titleStr.isEmpty else { return nil }

        if bundleID == "us.zoom.xos" || bundleID == "us.zoom.ZoomChat" {
            return titleStr.replacingOccurrences(of: " \\((\\d+)\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "Zoom Meeting", with: "")
                .replacingOccurrences(of: "Zoom", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " —-"))
        }
        if bundleID == "com.microsoft.teams" || bundleID == "com.microsoft.teams2" {
            return titleStr.replacingOccurrences(of: " \\(\\d+\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "Microsoft Teams", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " —-"))
        }
        if bundleID == "com.apple.FaceTime" {
            return titleStr
        }
        return titleStr
    }

    // MARK: - Session Management

    private func startNewSession(platform: String, title: String?, participants: [String],
                                 isPresenting: Bool = false, isSharing: Bool = false) {
        let session = MeetingSession(
            platform: platform,
            meetingTitle: title,
            participantCount: participants.count,
            participantNames: participants,
            isPresenting: isPresenting,
            isScreenSharing: isSharing
        )
        activeSession = session
        stream.continuation.yield(.meetingStarted(session))

        let recordAudio = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.recordMeetingAudio) as? Bool ?? false
        let useAI = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.useAIEnhancement) as? Bool ?? false
        if recordAudio && useAI {
            startTranscription()
        }
    }

    private func endCurrentSession() {
        guard let session = activeSession else { return }
        let ended = MeetingSession(
            id: session.id, platform: session.platform, meetingTitle: session.meetingTitle,
            participantCount: session.participantCount, participantNames: session.participantNames,
            isPresenting: session.isPresenting, isScreenSharing: session.isScreenSharing,
            startTime: session.startTime, endTime: Date(), hasTranscription: session.hasTranscription
        )
        activeSession = nil

        guard ended.duration >= 30 else { return }

        stopTranscription()
        transcriptionTask?.cancel()
        transcriptionTask = nil

        let meta = MeetingMetadata(
            platform: ended.platform,
            meetingTitle: ended.meetingTitle,
            participantCount: ended.participantCount,
            participantNames: ended.participantNames.joined(separator: ", "),
            isPresenting: ended.isPresenting,
            isScreenSharing: ended.isScreenSharing,
            transcriptionAvailable: !recognizedText.isEmpty,
            hasSummary: ended.hasTranscription
        )
        let metaJSON = (try? JSONEncoder().encode(meta)).flatMap { String(data: $0, encoding: .utf8) }

        let record = ActivityRecord(
            activityType: .meeting,
            category: "meeting",
            appBundleID: nil,
            appName: ended.platform,
            title: ended.meetingTitle,
            contentExcerpt: recognizedText.isEmpty ? nil : recognizedText,
            metadataJSON: metaJSON,
            duration: ended.duration,
            confidence: 0.85,
            source: "meeting_tracker",
            sessionID: ended.id
        )

        Task { @MainActor in
            await ActivityTracker.shared.insert(record)
        }

        stream.continuation.yield(.meetingEnded(ended, record))
    }

    // MARK: - Full Transcription

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizedText: String = ""
    private var speechRecognizer: SFSpeechRecognizer?

    private func startTranscription() {
        transcriptionTask = Task { [weak self] in
            guard await self?.requestSpeechPermission() == true else {
                await self?.log("Speech recognition not authorized")
                return
            }
            await self?.setupTranscription()
        }
    }

    private func setupTranscription() async {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else {
            log("Speech recognizer not available")
            return
        }

        self.speechRecognizer = recognizer
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            log("Transcription started")
        } catch {
            log("Failed to start audio engine: \(error.localizedDescription)")
            return
        }

        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { [weak self] in
                if let result {
                    let text = result.bestTranscription.formattedString
                    await self?.handleTranscriptionResult(text)
                }
                if error != nil {
                    await self?.stopTranscription()
                }
            }
        }
    }

    private func handleTranscriptionResult(_ text: String) {
        self.recognizedText = text
        if let sessionID = self.activeSession?.id {
            self.stream.continuation.yield(.transcriptionAvailable(sessionID: sessionID, text: text))
        }
    }

    private func stopTranscription() {
        self.audioEngine?.stop()
        self.audioEngine?.inputNode.removeTap(onBus: 0)
        self.recognitionRequest?.endAudio()
        self.recognitionTask?.cancel()
        self.audioEngine = nil
        self.recognitionRequest = nil
        self.recognitionTask = nil
        self.speechRecognizer = nil

        if !self.recognizedText.isEmpty {
            self.log("Transcription ended: \(self.recognizedText.count) characters")
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func log(_ message: String) {
        Log.info("MeetingTracker: \(message)")
    }
}
