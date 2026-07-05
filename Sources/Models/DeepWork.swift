import Foundation

public struct DeepWorkSession: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval
    public var activityType: ActivityType
    public var appName: String?
    public var focusScore: Double
    public var interruptions: Int

    public init(id: String = UUID().uuidString, startTime: Date, endTime: Date? = nil,
                duration: TimeInterval = 0, activityType: ActivityType = .reading,
                appName: String? = nil, focusScore: Double = 1.0, interruptions: Int = 0) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.activityType = activityType
        self.appName = appName
        self.focusScore = focusScore
        self.interruptions = interruptions
    }
}

public struct DeepWorkAnalysis: Codable, Sendable, Equatable {
    public var totalDeepWorkToday: TimeInterval
    public var sessionsToday: [DeepWorkSession]
    public var longestSessionToday: TimeInterval
    public var averageSessionDuration: TimeInterval
    public var deepWorkScore: Double
    public var contextSwitchesPerHour: Double
    public var peakDeepWorkHours: [Int]

    public init(totalDeepWorkToday: TimeInterval = 0, sessionsToday: [DeepWorkSession] = [],
                longestSessionToday: TimeInterval = 0, averageSessionDuration: TimeInterval = 0,
                deepWorkScore: Double = 0, contextSwitchesPerHour: Double = 0,
                peakDeepWorkHours: [Int] = []) {
        self.totalDeepWorkToday = totalDeepWorkToday
        self.sessionsToday = sessionsToday
        self.longestSessionToday = longestSessionToday
        self.averageSessionDuration = averageSessionDuration
        self.deepWorkScore = deepWorkScore
        self.contextSwitchesPerHour = contextSwitchesPerHour
        self.peakDeepWorkHours = peakDeepWorkHours
    }
}

public enum BurnoutRiskLevel: String, Codable, Sendable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
}

public enum WellbeingTrend: String, Codable, Sendable, CaseIterable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

public struct BurnoutSignals: Codable, Sendable, Equatable {
    public var overtimeHoursToday: TimeInterval
    public var nightWorkHoursThisWeek: TimeInterval
    public var weekendWorkHoursThisWeek: TimeInterval
    public var meetingOverloadRatio: Double
    public var contextSwitchesPerHour: Double
    public var averageWorkdayDuration: TimeInterval
    public var daysWorkedThisWeek: Int
    public var riskLevel: BurnoutRiskLevel
    public var wellbeingScore: Double
    public var wellbeingTrend: WellbeingTrend

    public init(overtimeHoursToday: TimeInterval = 0, nightWorkHoursThisWeek: TimeInterval = 0,
                weekendWorkHoursThisWeek: TimeInterval = 0, meetingOverloadRatio: Double = 0,
                contextSwitchesPerHour: Double = 0, averageWorkdayDuration: TimeInterval = 0,
                daysWorkedThisWeek: Int = 0, riskLevel: BurnoutRiskLevel = .low,
                wellbeingScore: Double = 100, wellbeingTrend: WellbeingTrend = .stable) {
        self.overtimeHoursToday = overtimeHoursToday
        self.nightWorkHoursThisWeek = nightWorkHoursThisWeek
        self.weekendWorkHoursThisWeek = weekendWorkHoursThisWeek
        self.meetingOverloadRatio = meetingOverloadRatio
        self.contextSwitchesPerHour = contextSwitchesPerHour
        self.averageWorkdayDuration = averageWorkdayDuration
        self.daysWorkedThisWeek = daysWorkedThisWeek
        self.riskLevel = riskLevel
        self.wellbeingScore = wellbeingScore
        self.wellbeingTrend = wellbeingTrend
    }
}
