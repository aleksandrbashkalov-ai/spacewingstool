import Foundation

public actor IntelligenceService {
    public static let shared = IntelligenceService()

    private init() {}

    // MARK: - Daily Report

    public func generateDailyReport(for date: Date) async throws -> DailyReport {
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            throw IntelligenceError.invalidDateRange
        }
        let range = dayStart...dayEnd

        let records = try await ActivityTracker.shared.records(in: range)
        let breakdown = try await ActivityTracker.shared.activityTypeSummary(in: range)

        let totalTime = records.reduce(0) { $0 + $1.duration }
        let topApps = extractTopApps(from: records, limit: 5)
        let topReading = extractTopTitles(from: records, type: .reading, limit: 3)
        let topWriting = extractTopTitles(from: records, type: .writing, limit: 3)
        let meetingsCount = records.filter { $0.activityType == .meeting }.count
        let emailsCount = records.filter { $0.activityType == .email }.count
        let musicPlayed = extractMusic(from: records)

        var breakdownDict: [String: TimeInterval] = [:]
        for (type, duration) in breakdown {
            breakdownDict[type.rawValue] = duration
        }

        let productivity = estimateProductivity(from: records, totalTime: totalTime)
        let keyEvents = extractKeyEvents(from: records)

        var report = DailyReport(
            date: date,
            totalActiveTime: totalTime,
            activityBreakdown: breakdownDict,
            topApps: topApps,
            topReading: topReading,
            topWriting: topWriting,
            meetingsCount: meetingsCount,
            emailsProcessed: emailsCount,
            musicPlayed: musicPlayed,
            estimatedProductivity: productivity,
            keyEvents: keyEvents
        )

        if useAIEnhancement() {
            report.aiSummary = try? await generateAISummary(for: report)
        }

        return report
    }

    // MARK: - Weekly Report

    public func generateWeeklyReport(weekStart: Date) async throws -> WeeklyReport {
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else {
            throw IntelligenceError.invalidDateRange
        }
        var dailyReports: [DailyReport] = []
        var allRecords: [ActivityRecord] = []
        var currentDate = weekStart

        while currentDate < weekEnd {
            let report = try await generateDailyReport(for: currentDate)
            dailyReports.append(report)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else {
                throw IntelligenceError.invalidDateRange
            }
            let dayRecords = try await ActivityTracker.shared.records(in: currentDate...dayEnd)
            allRecords.append(contentsOf: dayRecords)
            currentDate = dayEnd
        }

        let breakdown = try await ActivityTracker.shared.activityTypeSummary(in: weekStart...weekEnd)

        let totalTime = allRecords.reduce(0) { $0 + $1.duration }
        let topApps = extractTopApps(from: allRecords, limit: 5)
        let meetingsTotal = allRecords.filter { $0.activityType == .meeting }.count
        let emailsTotal = allRecords.filter { $0.activityType == .email }.count
        let avgProductivity = dailyReports.map { $0.estimatedProductivity }.reduce(0, +) / Double(max(dailyReports.count, 1))
        let trend = calculateTrend(from: dailyReports)

        var breakdownDict: [String: TimeInterval] = [:]
        for (type, duration) in breakdown {
            breakdownDict[type.rawValue] = duration
        }

        var report = WeeklyReport(
            weekStart: weekStart,
            weekEnd: weekEnd,
            dailyReports: dailyReports,
            totalActiveTime: totalTime,
            activityBreakdown: breakdownDict,
            topApps: topApps,
            meetingsTotal: meetingsTotal,
            emailsTotal: emailsTotal,
            avgProductivity: avgProductivity,
            trend: trend
        )

        if useAIEnhancement() {
            report.aiSummary = try? await generateAIWeeklySummary(for: report)
        }

        return report
    }

    // MARK: - Query

    public func query(_ query: String, period: ClosedRange<Date>) async throws -> QueryResult {
        let records = try await ActivityTracker.shared.records(in: period)

        let searchLower = query.lowercased()
        let filtered = records.filter { rec in
            rec.title?.lowercased().contains(searchLower) == true ||
            rec.appName?.lowercased().contains(searchLower) == true ||
            rec.category?.lowercased().contains(searchLower) == true ||
            rec.activityType.rawValue.lowercased().contains(searchLower)
        }

        let totalTime = filtered.reduce(0) { $0 + $1.duration }
        let typeSummary = Dictionary(grouping: filtered) { $0.activityType }
            .mapValues { records in records.reduce(0) { $0 + $1.duration } }

        let suggestedSpaces = suggestSpaces(from: filtered)
        _ = extractTopApps(from: filtered, limit: 3)

        let summaryParts: [String] = [
            "Found \(filtered.count) activities",
            "Total time: \(formatDuration(totalTime))",
        ] + typeSummary.map { "\($0.key.rawValue): \(formatDuration($0.value))" }
        let summary = summaryParts.joined(separator: "\n")

        var result = QueryResult(
            query: query,
            period: "\(formatDate(period.lowerBound)) — \(formatDate(period.upperBound))",
            records: filtered,
            summary: summary,
            suggestedSpaces: suggestedSpaces
        )

        if useAIEnhancement() {
            let aiSummary = try? await answerQuery(query: query, result: result)
            result.actionItems = aiSummary.map { [$0] } ?? []
        }

        return result
    }

    // MARK: - Task Extraction

    public func extractTasks(from records: [ActivityRecord]) async -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []
        for record in records {
            guard let title = record.title else { continue }
            let lowercaseTitle = title.lowercased()
            let actionWords = ["fix", "implement", "review", "update", "refactor",
                               "add", "remove", "change", "write", "create", "test",
                               "merge", "deploy", "check", "verify", "research"]
            for word in actionWords {
                guard lowercaseTitle.contains(word) else { continue }
                let task = ExtractedTask(
                    title: title,
                    source: record.appName ?? "Unknown",
                    sourceDetail: record.category,
                    detectedAt: record.timestamp,
                    deadline: extractDeadline(from: title),
                    priority: word == "fix" || word == "deploy" ? "high" : "medium"
                )
                tasks.append(task)
                break
            }
        }
        let extracted = Array(tasks.prefix(20))

        if useAIEnhancement() && !extracted.isEmpty {
            let prioritized = try? await prioritizeTasks(extracted)
            return prioritized ?? extracted
        }

        return extracted
    }

    // MARK: - AI Summary

    private func generateAISummary(for report: DailyReport) async throws -> String? {
        let provider = try resolveProvider()
        let (system, user) = AIPromptTemplates.dailySummary(report: report)
        return try await provider.generateSummary(systemPrompt: system, userMessage: user)
    }

    private func generateAIWeeklySummary(for report: WeeklyReport) async throws -> String? {
        let provider = try resolveProvider()
        let (system, user) = AIPromptTemplates.weeklySummary(report: report)
        return try await provider.generateSummary(systemPrompt: system, userMessage: user)
    }

    private func answerQuery(query: String, result: QueryResult) async throws -> String {
        let provider = try resolveProvider()
        let (system, user) = AIPromptTemplates.queryResponse(query: query, result: result)
        return try await provider.generateSummary(systemPrompt: system, userMessage: user)
    }

    private func prioritizeTasks(_ tasks: [ExtractedTask]) async throws -> [ExtractedTask] {
        let provider = try resolveProvider()
        let (system, user) = AIPromptTemplates.taskPrioritization(tasks: tasks)
        _ = try await provider.generateSummary(systemPrompt: system, userMessage: user)
        return tasks
    }

    // MARK: - Errors

    public enum IntelligenceError: LocalizedError {
        case invalidDateRange

        public var errorDescription: String? {
            switch self {
            case .invalidDateRange:
                return "The specified date range is invalid."
            }
        }
    }

    private func resolveProvider() throws -> AIProvider {
        let aiType = PrivacySettings.AIEnhancementType(
            rawValue: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.useAIType) ?? "Local AI Only"
        ) ?? .local

        switch aiType {
        case .local:
            return LocalAIProvider.shared
        case .remote, .both:
            return RemoteAIProvider.shared
        }
    }

    // MARK: - Helpers

    private func extractTopApps(from records: [ActivityRecord], limit: Int) -> [AppDuration] {
        let grouped = Dictionary(grouping: records) { $0.appName ?? "Unknown" }
        let sorted = grouped.map { AppDuration(name: $0.key, duration: $0.value.reduce(0) { $0 + $1.duration }) }
            .sorted { $0.duration > $1.duration }
        return Array(sorted.prefix(limit))
    }

    private func extractTopTitles(from records: [ActivityRecord], type: ActivityType, limit: Int) -> [String] {
        records.filter { $0.activityType == type }
            .compactMap { $0.title }
            .unique()
            .prefix(limit)
            .map { $0 }
    }

    private func extractMusic(from records: [ActivityRecord]) -> [String] {
        records.filter { $0.activityType == .media }
            .compactMap { $0.title }
            .unique()
    }

    private func extractKeyEvents(from records: [ActivityRecord]) -> [String] {
        var events: [String] = []
        for record in records where record.duration > 1800 {
            if let title = record.title {
                events.append("\(record.activityType.rawValue): \(title) (\(formatDuration(record.duration)))")
            }
        }
        return events
    }

    private func extractDeadline(from title: String) -> Date? {
        let patterns = [
            "by (\\d{1,2}/\\d{1,2})": "MM/dd",
            "due (\\d{1,2}/\\d{1,2})": "MM/dd",
        ]
        for (pattern, format) in patterns {
            if let range = title.range(of: pattern, options: .regularExpression) {
                let match = String(title[range])
                    .replacingOccurrences(of: "by ", with: "")
                    .replacingOccurrences(of: "due ", with: "")
                let formatter = DateFormatter()
                formatter.dateFormat = format
                if let date = formatter.date(from: match) {
                    return date
                }
            }
        }
        return nil
    }

    private func estimateProductivity(from records: [ActivityRecord], totalTime: TimeInterval) -> Double {
        guard totalTime > 0 else { return 0 }
        let productiveTypes: Set<ActivityType> = [.coding, .writing, .reading]
        let neutralTypes: Set<ActivityType> = [.email, .meeting]
        let productive = records.filter { productiveTypes.contains($0.activityType) }.reduce(0) { $0 + $1.duration }
        let neutral = records.filter { neutralTypes.contains($0.activityType) }.reduce(0) { $0 + $1.duration }
        return (productive * 1.0 + neutral * 0.5) / totalTime
    }

    private func calculateTrend(from reports: [DailyReport]) -> String {
        guard reports.count >= 3 else { return "insufficient data" }
        let recent = reports.suffix(3).map { $0.estimatedProductivity }
        let improving = recent[2] > recent[0]
        return improving ? "improving" : "declining"
    }

    private func suggestSpaces(from records: [ActivityRecord]) -> [String] {
        let types = Set(records.map { $0.activityType })
        var spaces: [String] = []
        if types.contains(.coding) || types.contains(.writing) { spaces.append("Deep Work") }
        if types.contains(.meeting) { spaces.append("Meetings") }
        if types.contains(.reading) { spaces.append("Research") }
        return spaces
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, HH:mm"
        return fmt.string(from: date)
    }

    private func useAIEnhancement() -> Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.useAIEnhancement) as? Bool ?? false
    }
}
