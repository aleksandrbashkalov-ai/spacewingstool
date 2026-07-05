import Foundation

public enum ActivityType: String, Codable, Sendable, CaseIterable {
    case reading
    case writing
    case email
    case media
    case meeting
    case browsing
    case coding
    case idle
}

public struct ActivityRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var timestamp: Date
    public var activityType: ActivityType
    public var category: String?
    public var appBundleID: String?
    public var appName: String?
    public var title: String?
    public var contentExcerpt: String?
    public var metadataJSON: String?
    public var duration: TimeInterval
    public var confidence: Double
    public var source: String
    public var isSummarized: Bool
    public var summaryID: String?
    public var sessionID: String?
    public var signalWeight: String?

    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        activityType: ActivityType,
        category: String? = nil,
        appBundleID: String? = nil,
        appName: String? = nil,
        title: String? = nil,
        contentExcerpt: String? = nil,
        metadataJSON: String? = nil,
        duration: TimeInterval = 0,
        confidence: Double = 1.0,
        source: String = "manual",
        isSummarized: Bool = false,
        summaryID: String? = nil,
        sessionID: String? = nil,
        signalWeight: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.activityType = activityType
        self.category = category
        self.appBundleID = appBundleID
        self.appName = appName
        self.title = title
        self.contentExcerpt = contentExcerpt
        self.metadataJSON = metadataJSON
        self.duration = duration
        self.confidence = confidence
        self.source = source
        self.isSummarized = isSummarized
        self.summaryID = summaryID
        self.sessionID = sessionID
        self.signalWeight = signalWeight
    }
}

public struct ReadingMetadata: Codable, Sendable {
    public var url: String?
    public var estimatedWords: Int?
    public var scrollDepth: Double?
    public var pageNumber: Int?
    public var totalPages: Int?
    public var readingTimeActive: TimeInterval?
    public var browser: String?

    public init(url: String? = nil, estimatedWords: Int? = nil, scrollDepth: Double? = nil, pageNumber: Int? = nil, totalPages: Int? = nil, readingTimeActive: TimeInterval? = nil, browser: String? = nil) {
        self.url = url
        self.estimatedWords = estimatedWords
        self.scrollDepth = scrollDepth
        self.pageNumber = pageNumber
        self.totalPages = totalPages
        self.readingTimeActive = readingTimeActive
        self.browser = browser
    }
}

public struct WritingMetadata: Codable, Sendable {
    public var documentName: String?
    public var wordCount: Int?
    public var keystrokeCount: Int?
    public var activeWritingTime: TimeInterval?
    public var documentPath: String?
    public var appBundleID: String?

    public init(documentName: String? = nil, wordCount: Int? = nil, keystrokeCount: Int? = nil, activeWritingTime: TimeInterval? = nil, documentPath: String? = nil, appBundleID: String? = nil) {
        self.documentName = documentName
        self.wordCount = wordCount
        self.keystrokeCount = keystrokeCount
        self.activeWritingTime = activeWritingTime
        self.documentPath = documentPath
        self.appBundleID = appBundleID
    }
}

public struct EmailMetadata: Codable, Sendable {
    public var sender: String?
    public var senderEmail: String?
    public var recipients: String?
    public var subject: String?
    public var isThread: Bool?
    public var messageCount: Int?
    public var hasDeadline: Bool?
    public var deadlineDate: Date?
    public var hasActionItem: Bool?
    public var priority: String?

    public init(sender: String? = nil, senderEmail: String? = nil, recipients: String? = nil, subject: String? = nil, isThread: Bool? = nil, messageCount: Int? = nil, hasDeadline: Bool? = nil, deadlineDate: Date? = nil, hasActionItem: Bool? = nil, priority: String? = nil) {
        self.sender = sender
        self.senderEmail = senderEmail
        self.recipients = recipients
        self.subject = subject
        self.isThread = isThread
        self.messageCount = messageCount
        self.hasDeadline = hasDeadline
        self.deadlineDate = deadlineDate
        self.hasActionItem = hasActionItem
        self.priority = priority
    }
}

public struct MediaMetadata: Codable, Sendable {
    public var trackName: String?
    public var artist: String?
    public var album: String?
    public var genre: String?
    public var duration: TimeInterval?
    public var platform: String?
    public var playbackRate: Double?

    public init(trackName: String? = nil, artist: String? = nil, album: String? = nil, genre: String? = nil, duration: TimeInterval? = nil, platform: String? = nil, playbackRate: Double? = nil) {
        self.trackName = trackName
        self.artist = artist
        self.album = album
        self.genre = genre
        self.duration = duration
        self.platform = platform
        self.playbackRate = playbackRate
    }
}

public struct MeetingMetadata: Codable, Sendable {
    public var platform: String?
    public var meetingTitle: String?
    public var participantCount: Int?
    public var participantNames: String?
    public var calendarEventID: String?
    public var isPresenting: Bool?
    public var isScreenSharing: Bool?
    public var transcriptionAvailable: Bool?
    public var hasSummary: Bool?

    public init(platform: String? = nil, meetingTitle: String? = nil, participantCount: Int? = nil, participantNames: String? = nil, calendarEventID: String? = nil, isPresenting: Bool? = nil, isScreenSharing: Bool? = nil, transcriptionAvailable: Bool? = nil, hasSummary: Bool? = nil) {
        self.platform = platform
        self.meetingTitle = meetingTitle
        self.participantCount = participantCount
        self.participantNames = participantNames
        self.calendarEventID = calendarEventID
        self.isPresenting = isPresenting
        self.isScreenSharing = isScreenSharing
        self.transcriptionAvailable = transcriptionAvailable
        self.hasSummary = hasSummary
    }
}

public struct ActivitySummary: Codable, Sendable, Identifiable {
    public var id: String
    public var periodStart: Date
    public var periodEnd: Date
    public var summaryType: String
    public var title: String
    public var summaryText: String
    public var keyPoints: [String]
    public var activityTypeBreakdown: [String: TimeInterval]
    public var aiGenerated: Bool
    public var providerID: String?

    public init(id: String = UUID().uuidString, periodStart: Date, periodEnd: Date, summaryType: String, title: String, summaryText: String, keyPoints: [String] = [], activityTypeBreakdown: [String: TimeInterval] = [:], aiGenerated: Bool = false, providerID: String? = nil) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.summaryType = summaryType
        self.title = title
        self.summaryText = summaryText
        self.keyPoints = keyPoints
        self.activityTypeBreakdown = activityTypeBreakdown
        self.aiGenerated = aiGenerated
        self.providerID = providerID
    }
}

public struct PrivacySettings: Codable, Sendable, Equatable {
    public var trackReading: Bool
    public var trackReadingContent: ContentCaptureLevel
    public var trackWriting: Bool
    public var trackWritingContent: WritingContentCapture
    public var trackEmail: Bool
    public var trackEmailBody: ContentCaptureLevel
    public var trackMedia: Bool
    public var trackMeetings: Bool
    public var recordMeetingAudio: Bool
    public var dataRetentionDays: Int
    public var useAIEnhancement: Bool
    public var useAIType: AIEnhancementType

    public enum ContentCaptureLevel: String, Codable, Sendable, CaseIterable {
        case off = "Off"
        case preview = "Preview Only"
        case full = "Full Content"
    }

    public enum WritingContentCapture: String, Codable, Sendable, CaseIterable {
        case off = "Off"
        case metadataOnly = "Metadata Only"
        case selectedText = "Selected Text"
    }

    public enum AIEnhancementType: String, Codable, Sendable, CaseIterable {
        case local = "Local AI Only"
        case remote = "Remote AI"
        case both = "Local + Remote"
    }

    public static let `default` = PrivacySettings(
        trackReading: false,
        trackReadingContent: .off,
        trackWriting: false,
        trackWritingContent: .off,
        trackEmail: false,
        trackEmailBody: .off,
        trackMedia: false,
        trackMeetings: false,
        recordMeetingAudio: false,
        dataRetentionDays: 30,
        useAIEnhancement: false,
        useAIType: .local
    )

    public init(trackReading: Bool, trackReadingContent: ContentCaptureLevel, trackWriting: Bool, trackWritingContent: WritingContentCapture, trackEmail: Bool, trackEmailBody: ContentCaptureLevel, trackMedia: Bool, trackMeetings: Bool, recordMeetingAudio: Bool, dataRetentionDays: Int, useAIEnhancement: Bool, useAIType: AIEnhancementType) {
        self.trackReading = trackReading
        self.trackReadingContent = trackReadingContent
        self.trackWriting = trackWriting
        self.trackWritingContent = trackWritingContent
        self.trackEmail = trackEmail
        self.trackEmailBody = trackEmailBody
        self.trackMedia = trackMedia
        self.trackMeetings = trackMeetings
        self.recordMeetingAudio = recordMeetingAudio
        self.dataRetentionDays = dataRetentionDays
        self.useAIEnhancement = useAIEnhancement
        self.useAIType = useAIType
    }
}
