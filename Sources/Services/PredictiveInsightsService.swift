import Foundation

public actor PredictiveInsightsService {
    public static let shared = PredictiveInsightsService()

    private let coachingService = CoachingService.shared
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Burnout Trend

    public func getBurnoutTrend(days: Int = 30) async -> [DailyBurnoutSnapshot] {
        var snapshots: [DailyBurnoutSnapshot] = []
        let today = Date()

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let signals = await coachingService.detectBurnoutSignals(for: date)
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
                  let records = try? await ActivityTracker.shared.records(in: dayStart...dayEnd) else { continue }

            let productiveTypes: Set<ActivityType> = [.coding, .writing, .reading]
            let deepWorkHours = records.filter { productiveTypes.contains($0.activityType) }.reduce(0) { $0 + $1.duration }
            let meetingHours = records.filter { $0.activityType == .meeting }.reduce(0) { $0 + $1.duration }

            let snapshot = DailyBurnoutSnapshot(
                date: date,
                wellbeingScore: signals.wellbeingScore,
                riskLevel: signals.riskLevel,
                deepWorkHours: deepWorkHours,
                meetingHours: meetingHours
            )
            snapshots.append(snapshot)
        }

        return snapshots.sorted { $0.date < $1.date }
    }

    // MARK: - Burnout Prediction

    public func predictBurnoutRisk(daysAhead: Int = 60) async -> BurnoutPrediction {
        let trend = await getBurnoutTrend(days: 30)
        guard trend.count >= 7 else {
            return BurnoutPrediction(
                predictedRiskLevel: .low,
                predictedWellbeingScore: 100,
                confidenceInterval: 0...100,
                daysAhead: daysAhead
            )
        }

        let scores = trend.map { $0.wellbeingScore }
        let xMean = Double(scores.count - 1) / 2
        let yMean = scores.reduce(0, +) / Double(scores.count)

        var num = 0.0
        var den = 0.0
        for i in scores.indices {
            let x = Double(i)
            num += (x - xMean) * (scores[i] - yMean)
            den += (x - xMean) * (x - xMean)
        }

        let slope = den > 0 ? num / den : 0
        let intercept = yMean - slope * xMean
        let predictedScore = intercept + slope * Double(scores.count - 1 + daysAhead)
        let clampedScore = max(0, min(100, predictedScore))

        let predictedRisk: BurnoutRiskLevel
        if clampedScore >= 80 { predictedRisk = .low }
        else if clampedScore >= 60 { predictedRisk = .moderate }
        else if clampedScore >= 40 { predictedRisk = .high }
        else { predictedRisk = .critical }

        let residuals = scores.enumerated().map { (i, y) in
            let predicted = intercept + slope * Double(i)
            return abs(y - predicted)
        }
        let mae = residuals.reduce(0, +) / Double(residuals.count)
        let ci = (clampedScore - mae)...min(100, clampedScore + mae)

        return BurnoutPrediction(
            predictedRiskLevel: predictedRisk,
            predictedWellbeingScore: clampedScore,
            confidenceInterval: ci,
            daysAhead: daysAhead
        )
    }

    // MARK: - Weekly Patterns

    public func getWeeklyPatterns() async -> [WeeklyPattern] {
        var dayData: [Int: [Double]] = [:]
        var dayDeepWork: [Int: [TimeInterval]] = [:]
        var dayMeetings: [Int: [TimeInterval]] = [:]

        let trend = await getBurnoutTrend(days: 28)

        for snapshot in trend {
            let weekday = calendar.component(.weekday, from: snapshot.date)
            dayData[weekday, default: []].append(snapshot.wellbeingScore)
            dayDeepWork[weekday, default: []].append(snapshot.deepWorkHours)
            dayMeetings[weekday, default: []].append(snapshot.meetingHours)
        }

        var patterns: [WeeklyPattern] = []
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        for weekday in 1...7 {
            guard let scores = dayData[weekday], !scores.isEmpty,
                  let deepWork = dayDeepWork[weekday],
                  let meetings = dayMeetings[weekday] else { continue }

            let avgWellbeing = scores.reduce(0, +) / Double(scores.count)
            let avgDeep = deepWork.reduce(0, +) / Double(deepWork.count)
            let avgMeeting = meetings.reduce(0, +) / Double(meetings.count)

            var insight: String
            if avgWellbeing < 60 {
                insight = "Low wellbeing — consider lighter schedule"
            } else if avgDeep < 1800 {
                insight = "Low deep work — protect focus time"
            } else if avgMeeting > 7200 {
                insight = "Heavy meeting day — batch them together"
            } else if avgWellbeing > 85 {
                insight = "High wellbeing — your productive day"
            } else {
                insight = "Balanced day"
            }

            patterns.append(WeeklyPattern(
                dayName: dayNames[weekday],
                weekday: weekday,
                avgDeepWorkHours: avgDeep,
                avgMeetingHours: avgMeeting,
                avgWellbeingScore: avgWellbeing,
                insight: insight
            ))
        }

        return patterns
    }

    // MARK: - Productivity Forecast

    public func forecastProductivity(days: Int = 7) async -> ProductivityForecast {
        let trend = await getBurnoutTrend(days: 14)
        guard trend.count >= 3 else {
            return ProductivityForecast(forecastedScore: 50, trend: 0, confidenceInterval: 0...100)
        }

        let scores = trend.map { $0.wellbeingScore }
        let xMean = Double(scores.count - 1) / 2
        let yMean = scores.reduce(0, +) / Double(scores.count)

        var num = 0.0
        var den = 0.0
        for i in scores.indices {
            let x = Double(i)
            num += (x - xMean) * (scores[i] - yMean)
            den += (x - xMean) * (x - xMean)
        }

        let slope = den > 0 ? num / den : 0
        let forecasted = yMean + slope * Double(days)
        let clamped = max(0, min(100, forecasted))

        let residuals = scores.enumerated().map { (i, y) in
            let predicted = yMean + slope * (Double(i) - xMean)
            return abs(y - predicted)
        }
        let mae = residuals.reduce(0, +) / Double(residuals.count)
        let ci = (clamped - mae)...min(100, clamped + mae)

        return ProductivityForecast(
            forecastedScore: clamped,
            trend: slope,
            confidenceInterval: ci
        )
    }
}
