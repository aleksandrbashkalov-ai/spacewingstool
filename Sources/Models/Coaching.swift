import Foundation

public enum AdviceType: String, Codable, Sendable, CaseIterable {
    case productivity = "Productivity"
    case focus = "Focus"
    case wellbeing = "Wellbeing"
    case organization = "Organization"
    case learning = "Learning"
}

public enum AdvicePriority: String, Codable, Sendable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

public struct CoachingAdvice: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var type: AdviceType
    public var title: String
    public var description: String
    public var priority: AdvicePriority
    public var actionItem: String?
    public var category: String?
    public var timestamp: Date
    public var isRead: Bool
    public var isDismissed: Bool

    public init(id: String = UUID().uuidString, type: AdviceType, title: String,
                description: String, priority: AdvicePriority = .medium,
                actionItem: String? = nil, category: String? = nil,
                timestamp: Date = Date(), isRead: Bool = false, isDismissed: Bool = false) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionItem = actionItem
        self.category = category
        self.timestamp = timestamp
        self.isRead = isRead
        self.isDismissed = isDismissed
    }
}

public struct CoachingReport: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var date: Date
    public var type: CoachingReportType
    public var summary: String
    public var deepWorkAnalysis: DeepWorkAnalysis
    public var burnoutSignals: BurnoutSignals
    public var topAdvice: [CoachingAdvice]
    public var productivityTrend: String
    public var aiGenerated: Bool

    public init(id: String = UUID().uuidString, date: Date = Date(),
                type: CoachingReportType = .daily, summary: String = "",
                deepWorkAnalysis: DeepWorkAnalysis = DeepWorkAnalysis(),
                burnoutSignals: BurnoutSignals = BurnoutSignals(),
                topAdvice: [CoachingAdvice] = [], productivityTrend: String = "stable",
                aiGenerated: Bool = false) {
        self.id = id
        self.date = date
        self.type = type
        self.summary = summary
        self.deepWorkAnalysis = deepWorkAnalysis
        self.burnoutSignals = burnoutSignals
        self.topAdvice = topAdvice
        self.productivityTrend = productivityTrend
        self.aiGenerated = aiGenerated
    }
}

public enum CoachingReportType: String, Codable, Sendable {
    case daily = "Daily"
    case weekly = "Weekly"
    case realtime = "Realtime"
}

public struct TrackerState: Codable, Sendable, Equatable {
    public var isReadingActive: Bool
    public var isWritingActive: Bool
    public var isEmailActive: Bool
    public var isMediaActive: Bool
    public var isMeetingActive: Bool
    public var currentReadingTitle: String?
    public var currentWritingApp: String?
    public var currentEmailSubject: String?
    public var currentTrackInfo: String?
    public var currentMeetingTitle: String?
    public var lastUpdated: Date

    public init(isReadingActive: Bool = false, isWritingActive: Bool = false,
                isEmailActive: Bool = false, isMediaActive: Bool = false,
                isMeetingActive: Bool = false,
                currentReadingTitle: String? = nil, currentWritingApp: String? = nil,
                currentEmailSubject: String? = nil, currentTrackInfo: String? = nil,
                currentMeetingTitle: String? = nil, lastUpdated: Date = Date()) {
        self.isReadingActive = isReadingActive
        self.isWritingActive = isWritingActive
        self.isEmailActive = isEmailActive
        self.isMediaActive = isMediaActive
        self.isMeetingActive = isMeetingActive
        self.currentReadingTitle = currentReadingTitle
        self.currentWritingApp = currentWritingApp
        self.currentEmailSubject = currentEmailSubject
        self.currentTrackInfo = currentTrackInfo
        self.currentMeetingTitle = currentMeetingTitle
        self.lastUpdated = lastUpdated
    }
}
