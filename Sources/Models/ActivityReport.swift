import Foundation

public struct AppDuration: Codable, Sendable, Equatable {
    public var name: String
    public var duration: TimeInterval

    public init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
    }
}

public struct DailyReport: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var date: Date
    public var totalActiveTime: TimeInterval
    public var activityBreakdown: [String: TimeInterval]
    public var topApps: [AppDuration]
    public var topReading: [String]
    public var topWriting: [String]
    public var meetingsCount: Int
    public var emailsProcessed: Int
    public var musicPlayed: [String]
    public var estimatedProductivity: Double
    public var keyEvents: [String]
    public var aiSummary: String?

    public init(id: String = UUID().uuidString, date: Date, totalActiveTime: TimeInterval = 0,
                activityBreakdown: [String: TimeInterval] = [:],
                topApps: [AppDuration] = [], topReading: [String] = [],
                topWriting: [String] = [], meetingsCount: Int = 0, emailsProcessed: Int = 0,
                musicPlayed: [String] = [], estimatedProductivity: Double = 0,
                keyEvents: [String] = [], aiSummary: String? = nil) {
        self.id = id
        self.date = date
        self.totalActiveTime = totalActiveTime
        self.activityBreakdown = activityBreakdown
        self.topApps = topApps
        self.topReading = topReading
        self.topWriting = topWriting
        self.meetingsCount = meetingsCount
        self.emailsProcessed = emailsProcessed
        self.musicPlayed = musicPlayed
        self.estimatedProductivity = estimatedProductivity
        self.keyEvents = keyEvents
        self.aiSummary = aiSummary
    }
}

public struct WeeklyReport: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var weekStart: Date
    public var weekEnd: Date
    public var dailyReports: [DailyReport]
    public var totalActiveTime: TimeInterval
    public var activityBreakdown: [String: TimeInterval]
    public var topApps: [AppDuration]
    public var meetingsTotal: Int
    public var emailsTotal: Int
    public var avgProductivity: Double
    public var trend: String
    public var aiSummary: String?

    public init(id: String = UUID().uuidString, weekStart: Date, weekEnd: Date,
                dailyReports: [DailyReport] = [], totalActiveTime: TimeInterval = 0,
                activityBreakdown: [String: TimeInterval] = [:],
                topApps: [AppDuration] = [], meetingsTotal: Int = 0,
                emailsTotal: Int = 0, avgProductivity: Double = 0, trend: String = "",
                aiSummary: String? = nil) {
        self.id = id
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.dailyReports = dailyReports
        self.totalActiveTime = totalActiveTime
        self.activityBreakdown = activityBreakdown
        self.topApps = topApps
        self.meetingsTotal = meetingsTotal
        self.emailsTotal = emailsTotal
        self.avgProductivity = avgProductivity
        self.trend = trend
        self.aiSummary = aiSummary
    }
}

public struct QueryResult: Codable, Sendable, Equatable {
    public var query: String
    public var period: String
    public var records: [ActivityRecord]
    public var summary: String
    public var suggestedSpaces: [String]
    public var actionItems: [String]

    public init(query: String, period: String, records: [ActivityRecord] = [],
                summary: String = "", suggestedSpaces: [String] = [],
                actionItems: [String] = []) {
        self.query = query
        self.period = period
        self.records = records
        self.summary = summary
        self.suggestedSpaces = suggestedSpaces
        self.actionItems = actionItems
    }
}

public struct ExtractedTask: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var source: String
    public var sourceDetail: String?
    public var detectedAt: Date
    public var deadline: Date?
    public var isCompleted: Bool
    public var priority: String

    public init(id: String = UUID().uuidString, title: String, source: String,
                sourceDetail: String? = nil, detectedAt: Date = Date(), deadline: Date? = nil,
                isCompleted: Bool = false, priority: String = "medium") {
        self.id = id
        self.title = title
        self.source = source
        self.sourceDetail = sourceDetail
        self.detectedAt = detectedAt
        self.deadline = deadline
        self.isCompleted = isCompleted
        self.priority = priority
    }
}
