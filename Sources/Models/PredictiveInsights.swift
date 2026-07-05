import Foundation

public struct DailyBurnoutSnapshot: Codable, Sendable, Identifiable, Equatable {
    public var id: String { date.ISO8601Format() }
    public var date: Date
    public var wellbeingScore: Double
    public var riskLevel: BurnoutRiskLevel
    public var deepWorkHours: TimeInterval
    public var meetingHours: TimeInterval
}

public struct BurnoutPrediction: Codable, Sendable, Equatable {
    public var predictedRiskLevel: BurnoutRiskLevel
    public var predictedWellbeingScore: Double
    public var confidenceInterval: ClosedRange<Double>
    public var daysAhead: Int
}

public struct WeeklyPattern: Codable, Sendable, Identifiable, Equatable {
    public var id: String { dayName }
    public var dayName: String
    public var weekday: Int
    public var avgDeepWorkHours: TimeInterval
    public var avgMeetingHours: TimeInterval
    public var avgWellbeingScore: Double
    public var insight: String
}

public struct ProductivityForecast: Codable, Sendable, Equatable {
    public var forecastedScore: Double
    public var trend: Double
    public var confidenceInterval: ClosedRange<Double>
}
