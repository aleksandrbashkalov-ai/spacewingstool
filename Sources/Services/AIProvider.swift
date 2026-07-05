import Foundation

public enum AIProviderError: LocalizedError {
    case notConfigured(String)
    case invalidEndpoint
    case requestFailed(String)
    case invalidResponse
    case providerUnavailable

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let detail): return "AI provider not configured: \(detail)"
        case .invalidEndpoint: return "Invalid endpoint URL configured"
        case .requestFailed(let detail): return "AI request failed: \(detail)"
        case .invalidResponse: return "Invalid response from AI provider"
        case .providerUnavailable: return "AI provider is not available"
        }
    }
}

public protocol AIProvider: Sendable {
    func generateSummary(systemPrompt: String, userMessage: String) async throws -> String
}

public enum AIPromptTemplates {
    public static func dailySummary(report: DailyReport) -> (system: String, user: String) {
        let system = """
        You are a productivity assistant analyzing a daily activity report. \
        Provide a concise, actionable summary in 3-5 sentences. Highlight \
        top activities, productivity trends, and suggest one improvement.
        """
        let breakdownLines = report.activityBreakdown
            .map { "  - \($0.key): \(formatDuration($0.value))" }
            .joined(separator: "\n")
        let user = """
        Daily Activity Report:
        - Total Active Time: \(formatDuration(report.totalActiveTime))
        - Estimated Productivity: \(Int(report.estimatedProductivity * 100))%
        - Meetings: \(report.meetingsCount)
        - Emails Processed: \(report.emailsProcessed)
        - Top Apps: \(report.topApps.map(\.name).joined(separator: ", "))
        - Top Reading: \(report.topReading.joined(separator: ", "))
        - Top Writing: \(report.topWriting.joined(separator: ", "))

        Activity Breakdown:
        \(breakdownLines)

        Key Events:
        \(report.keyEvents.map { "  - \($0)" }.joined(separator: "\n"))
        """
        return (system, user)
    }

    public static func weeklySummary(report: WeeklyReport) -> (system: String, user: String) {
        let system = """
        You are a productivity assistant analyzing a weekly activity report. \
        Summarize trends, compare days, and provide 2-3 actionable recommendations \
        for the upcoming week.
        """
        let user = """
        Weekly Activity Report (\(formatDate(report.weekStart)) - \(formatDate(report.weekEnd))):
        - Total Active Time: \(formatDuration(report.totalActiveTime))
        - Average Daily Productivity: \(Int(report.avgProductivity * 100))%
        - Trend: \(report.trend)
        - Total Meetings: \(report.meetingsTotal)
        - Total Emails: \(report.emailsTotal)

        Daily Breakdown:
        \(report.dailyReports.map { day in
            "  \(formatDate(day.date)): \(formatDuration(day.totalActiveTime)) (prod: \(Int(day.estimatedProductivity * 100))%)"
        }.joined(separator: "\n"))

        Top Apps This Week: \(report.topApps.map(\.name).joined(separator: ", "))
        """
        return (system, user)
    }

    public static func queryResponse(query: String, result: QueryResult) -> (system: String, user: String) {
        let system = """
        You are an assistant answering questions about the user's activity history. \
        Use the provided data to answer concisely and accurately. If the data doesn't \
        fully answer the question, say so.
        """
        let user = """
        Query: "\(query)"
        Period: \(result.period)
        Found \(result.records.count) relevant activities.

        Summary:
        \(result.summary)

        Please answer the query based on this data.
        """
        return (system, user)
    }

    public static func taskPrioritization(tasks: [ExtractedTask]) -> (system: String, user: String) {
        let system = """
        You are a task management assistant. Review the extracted tasks and \
        prioritize them. Group by urgency, suggest deadlines, and identify \
        the top 3 most important tasks.
        """
        let taskLines = tasks.map { t in
            let deadline = t.deadline.map { " (due: \(formatDate($0)))" } ?? ""
            return "  - [\(t.priority)] \(t.title) — from \(t.source)\(deadline)"
        }.joined(separator: "\n")
        let user = """
        Extracted Tasks (\(tasks.count)):
        \(taskLines)

        Please prioritize these tasks and recommend the top 3.
        """
        return (system, user)
    }

    // MARK: - Coaching Advice

    public static func coachingAdvice(advice: [CoachingAdvice]) -> (system: String, user: String) {
        let system = """
        You are an AI productivity coach. Review the detected patterns and \
        provide personalized, actionable advice. Be concise and specific. \
        For each piece of advice, output one line: "Title: Description".
        """
        let adviceLines = advice.map { a in
            "[\(a.priority.rawValue)] \(a.type.rawValue): \(a.title) — \(a.description)"
        }.joined(separator: "\n")
        let user = """
        Current advice candidates:
        \(adviceLines)

        Refine and enhance each piece of advice with specific, actionable guidance.
        """
        return (system, user)
    }

    // MARK: - Per-Category AI Agents

    public static func readingAgent(sessions: [ReadingSession]) -> (system: String, user: String) {
        let system = """
        You are a Reading Intelligence Agent. Analyze the user's reading activity \
        and provide insights about content consumption patterns, reading speed, \
        and suggestions for better information retention.
        """
        let sessionLines = sessions.map { s in
            "  - \"\(s.title)\" on \(s.browser) (\(Int(s.duration / 60)) min, \(s.wordsRead) words)"
        }.joined(separator: "\n")
        let user = "Reading Sessions:\n\(sessionLines)"
        return (system, user)
    }

    public static func writingAgent(sessions: [EditingSession]) -> (system: String, user: String) {
        let system = """
        You are a Writing Intelligence Agent. Analyze writing sessions and \
        provide insights about writing velocity, document focus, and suggestions \
        for improving writing productivity.
        """
        let sessionLines = sessions.map { s in
            "  - \"\(s.documentName ?? "Untitled")\" in \(s.appName) (\(Int(s.duration / 60)) min, \(s.keystrokeCount) keystrokes, \(Int(s.averageWPM)) WPM)"
        }.joined(separator: "\n")
        let user = "Writing Sessions:\n\(sessionLines)"
        return (system, user)
    }

    public static func emailAgent(sessions: [EmailSession]) -> (system: String, user: String) {
        let system = """
        You are an Email Intelligence Agent. Analyze email activity and provide \
        insights about communication patterns, response times, and suggestions \
        for email management.
        """
        let sessionLines = sessions.map { s in
            "  - From: \(s.senderName ?? "Unknown") — \"\(s.subject ?? "No subject")\" (\(Int(s.duration / 60)) min)"
        }.joined(separator: "\n")
        let user = "Email Sessions:\n\(sessionLines)"
        return (system, user)
    }

    public static func mediaAgent(tracks: [MediaTrack]) -> (system: String, user: String) {
        let system = """
        You are a Media Intelligence Agent. Analyze music listening patterns \
        and provide insights about how media consumption affects productivity, \
        mood, and focus.
        """
        let trackLines = tracks.map { t in
            "  - \(t.artist) — \(t.title) (\(t.platform), \(Int(t.duration / 60)) min)"
        }.joined(separator: "\n")
        let user = "Recent Tracks:\n\(trackLines)"
        return (system, user)
    }

    public static func meetingAgent(sessions: [MeetingSession]) -> (system: String, user: String) {
        let system = """
        You are a Meeting Intelligence Agent. Analyze meeting patterns and \
        provide insights about meeting efficiency, participation, and suggestions \
        for reducing meeting overload.
        """
        let sessionLines = sessions.map { s in
            "  - \"\(s.meetingTitle ?? "Untitled")\" on \(s.platform) (\(s.participantCount) participants, \(Int(s.duration / 60)) min)"
        }.joined(separator: "\n")
        let user = "Recent Meetings:\n\(sessionLines)"
        return (system, user)
    }

    public static func coachingPrompt(deepWork: DeepWorkAnalysis, burnout: BurnoutSignals) -> (system: String, user: String) {
        let system = """
        You are an AI productivity coach. Based on the user's deep work analysis \
        and burnout signals, provide 3-5 specific, actionable recommendations. \
        Format each recommendation as a bullet point with a brief explanation.
        """
        let user = """
        Deep Work Analysis:
        - Score: \(Int(deepWork.deepWorkScore))/100
        - Total Today: \(formatDuration(deepWork.totalDeepWorkToday))
        - Sessions: \(deepWork.sessionsToday.count)
        - Longest Session: \(formatDuration(deepWork.longestSessionToday))
        - Context Switches/hour: \(Int(deepWork.contextSwitchesPerHour))

        Burnout Signals:
        - Risk Level: \(burnout.riskLevel.rawValue)
        - Overtime Today: \(formatDuration(burnout.overtimeHoursToday))
        - Night Work This Week: \(formatDuration(burnout.nightWorkHoursThisWeek))
        - Meeting Overload: \(Int(burnout.meetingOverloadRatio * 100))%
        - Avg Workday: \(formatDuration(burnout.averageWorkdayDuration))

        Provide specific, actionable coaching advice.
        """
        return (system, user)
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, HH:mm"
        return fmt.string(from: date)
    }
}
