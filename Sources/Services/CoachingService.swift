import Foundation

public actor CoachingService {
    public static let shared = CoachingService()

    private var recentAdvice: [CoachingAdvice] = []
    private var monitoringTask: Task<Void, Never>?

    private init() {}

    // MARK: - Lifecycle

    public func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkForRealtimeAdvice()
                try? await Task.sleep(nanoseconds: 300_000_000_000)
            }
        }
        Log.info("CoachingService started")
    }

    public func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        Log.info("CoachingService stopped")
    }

    // MARK: - Daily Coaching Report

    public func generateDailyReport(for date: Date) async -> CoachingReport {
        let deepWork = await analyzeDeepWork(for: date)
        let burnout = await detectBurnoutSignals(for: date)
        let advice = await generateAdvice(deepWork: deepWork, burnout: burnout)

        let summary = buildSummary(deepWork: deepWork, burnout: burnout, advice: advice)

        let report = CoachingReport(
            date: date,
            type: .daily,
            summary: summary,
            deepWorkAnalysis: deepWork,
            burnoutSignals: burnout,
            topAdvice: advice,
            productivityTrend: "stable"
        )

        recentAdvice = advice
        Log.info("Coaching report generated for \(date)")
        return report
    }

    public func generateRealtimeAdvice() async -> [CoachingAdvice] {
        let now = Date()
        let deepWork = await analyzeDeepWork(for: now)
        let burnout = await detectBurnoutSignals(for: now)
        let advice = await generateAdvice(deepWork: deepWork, burnout: burnout)
        recentAdvice = advice
        return advice
    }

    // MARK: - Deep Work Analysis

    public func analyzeDeepWork(for date: Date) async -> DeepWorkAnalysis {
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return DeepWorkAnalysis()
        }
        let range = dayStart...dayEnd

        guard let records = try? await ActivityTracker.shared.records(in: range) else {
            return DeepWorkAnalysis()
        }

        let productiveTypes: Set<ActivityType> = [.coding, .writing, .reading]
        let deepWorkRecords = records.filter { productiveTypes.contains($0.activityType) }
            .sorted { $0.timestamp < $1.timestamp }

        var sessions: [DeepWorkSession] = []
        var currentSession: DeepWorkSession?
        let minDeepWorkDuration: TimeInterval = 900
        let maxGap: TimeInterval = 300

        for record in deepWorkRecords {
            guard let start = currentSession else {
                currentSession = DeepWorkSession(
                    startTime: record.timestamp,
                    activityType: record.activityType,
                    appName: record.appName,
                    focusScore: record.confidence
                )
                continue
            }

            let gap = record.timestamp.timeIntervalSince(start.startTime + start.duration)
            if gap > maxGap || record.activityType != start.activityType {
                if start.duration >= minDeepWorkDuration {
                    var ended = start
                    ended.endTime = start.startTime + start.duration
                    sessions.append(ended)
                }
                currentSession = DeepWorkSession(
                    startTime: record.timestamp,
                    activityType: record.activityType,
                    appName: record.appName,
                    focusScore: record.confidence
                )
            } else {
                var updated = start
                updated.duration += record.duration
                updated.interruptions += gap > 60 ? 1 : 0
                currentSession = updated
            }
        }

        if let last = currentSession, last.duration >= minDeepWorkDuration {
            var ended = last
            ended.endTime = ended.startTime + ended.duration
            sessions.append(ended)
        }

        let totalTime = sessions.reduce(0) { $0 + $1.duration }
        let longest = sessions.map(\.duration).max() ?? 0
        let avgDuration = sessions.isEmpty ? 0 : totalTime / Double(sessions.count)

        let activeSeconds = records.reduce(0) { $0 + $1.duration }
        let switches = countContextSwitches(in: records)
        let switchesPerHour = activeSeconds > 0 ? Double(switches) / (activeSeconds / 3600) : 0

        let deepWorkRatio = activeSeconds > 0 ? totalTime / activeSeconds : 0
        let score = min(deepWorkRatio * 100 + min(totalTime / 3600, 4) * 15, 100)

        let peakHours = findPeakHours(from: sessions)

        return DeepWorkAnalysis(
            totalDeepWorkToday: totalTime,
            sessionsToday: sessions,
            longestSessionToday: longest,
            averageSessionDuration: avgDuration,
            deepWorkScore: score,
            contextSwitchesPerHour: switchesPerHour,
            peakDeepWorkHours: peakHours
        )
    }

    // MARK: - Burnout Detection

    public func detectBurnoutSignals(for date: Date) async -> BurnoutSignals {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return BurnoutSignals()
        }
        let range = dayStart...dayEnd

        guard let records = try? await ActivityTracker.shared.records(in: range) else {
            return BurnoutSignals()
        }

        let now = Date()
        let isWorkHours = (9...18).contains(calendar.component(.hour, from: now))

        let totalActiveTime = records.reduce(0) { $0 + $1.duration }
        let overtimeHoursToday = isWorkHours ? max(totalActiveTime - 28800, 0) : totalActiveTime

        var nightWorkThisWeek: TimeInterval = 0
        var weekendWorkThisWeek: TimeInterval = 0
        var daysWorked: Set<Int> = []
        var workdayDurations: [TimeInterval] = []

        for dayOffset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: date)!
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)),
                  let dayRecords = try? await ActivityTracker.shared.records(in: calendar.startOfDay(for: day)...nextDay) else { continue }

            let dayTotal = dayRecords.reduce(0) { $0 + $1.duration }
            if dayTotal > 3600 {
                daysWorked.insert(calendar.component(.weekday, from: day))
                workdayDurations.append(dayTotal)
            }

            for record in dayRecords {
                let hour = calendar.component(.hour, from: record.timestamp)
                if hour < 7 || hour >= 22 {
                    nightWorkThisWeek += record.duration
                }
            }

            let isWeekend = calendar.isDateInWeekend(day)
            if isWeekend {
                weekendWorkThisWeek += dayTotal
            }
        }

        let meetingDuration = records.filter { $0.activityType == .meeting }.reduce(0) { $0 + $1.duration }
        let meetingOverloadRatio = totalActiveTime > 0 ? meetingDuration / totalActiveTime : 0

        let switches = countContextSwitches(in: records)
        let switchesPerHour = totalActiveTime > 0 ? Double(switches) / (totalActiveTime / 3600) : 0

        let avgWorkdayDuration = workdayDurations.isEmpty ? 0 : workdayDurations.reduce(0, +) / Double(workdayDurations.count)

        let riskLevel = calculateBurnoutRisk(
            overtimeHours: overtimeHoursToday,
            nightWork: nightWorkThisWeek,
            weekendWork: weekendWorkThisWeek,
            meetingOverload: meetingOverloadRatio,
            avgWorkday: avgWorkdayDuration
        )

        let wellbeingScore = calculateWellbeingScore(
            overtimeHours: overtimeHoursToday,
            nightWork: nightWorkThisWeek,
            weekendWork: weekendWorkThisWeek,
            meetingOverload: meetingOverloadRatio,
            contextSwitches: switchesPerHour,
            avgWorkday: avgWorkdayDuration
        )

        let previousScore = await computePreviousWellbeingScore(for: date, calendar: calendar)

        let trend: WellbeingTrend = {
            let diff = wellbeingScore - previousScore
            if diff > 5 { return .improving }
            if diff < -5 { return .declining }
            return .stable
        }()

        return BurnoutSignals(
            overtimeHoursToday: overtimeHoursToday,
            nightWorkHoursThisWeek: nightWorkThisWeek,
            weekendWorkHoursThisWeek: weekendWorkThisWeek,
            meetingOverloadRatio: meetingOverloadRatio,
            contextSwitchesPerHour: switchesPerHour,
            averageWorkdayDuration: avgWorkdayDuration,
            daysWorkedThisWeek: daysWorked.count,
            riskLevel: riskLevel,
            wellbeingScore: wellbeingScore,
            wellbeingTrend: trend
        )
    }

    // MARK: - Advice Generation

    public func generateAdvice(deepWork: DeepWorkAnalysis, burnout: BurnoutSignals) async -> [CoachingAdvice] {
        var advice: [CoachingAdvice] = []

        if deepWork.deepWorkScore < 30 {
            advice.append(CoachingAdvice(
                type: .focus,
                title: "Low Deep Work Score",
                description: "Your deep work score is \(Int(deepWork.deepWorkScore))/100. Try blocking 2-hour focus sessions in your calendar.",
                priority: .high,
                actionItem: "Schedule a 2-hour focus block tomorrow morning",
                category: "focus"
            ))
        }

        if deepWork.contextSwitchesPerHour > 10 {
            advice.append(CoachingAdvice(
                type: .productivity,
                title: "Frequent Context Switching",
                description: "You're switching context \(Int(deepWork.contextSwitchesPerHour))x/hour. High switching reduces cognitive performance.",
                priority: .medium,
                actionItem: "Try batching similar tasks together",
                category: "productivity"
            ))
        }

        if deepWork.totalDeepWorkToday < 3600 {
            advice.append(CoachingAdvice(
                type: .focus,
                title: "Less Than 1 Hour of Deep Work",
                description: "Aim for at least 2 hours of deep work daily for peak cognitive performance.",
                priority: .medium,
                actionItem: "Identify your peak energy hours and protect them",
                category: "focus"
            ))
        }

        if burnout.riskLevel == .high || burnout.riskLevel == .critical {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Burnout Risk: \(burnout.riskLevel.rawValue)",
                description: "Your work patterns show signs of overwork. Consider taking breaks and setting boundaries.",
                priority: .critical,
                actionItem: "Take a 15-minute break now and review your workload",
                category: "wellbeing"
            ))
        }

        if burnout.overtimeHoursToday > 7200 {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Overtime Alert",
                description: "You've worked \(burnout.overtimeHoursToday.formatDuration()) overtime today. Extended hours reduce productivity.",
                priority: .high,
                actionItem: "Set a hard stop time for today",
                category: "wellbeing"
            ))
        }

        if burnout.nightWorkHoursThisWeek > 10800 {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Night Work Pattern Detected",
                description: "Late-night work affects sleep quality and next-day performance.",
                priority: .high,
                actionItem: "Wind down 1 hour before bed — no screens",
                category: "wellbeing"
            ))
        }

        if burnout.meetingOverloadRatio > 0.4 {
            advice.append(CoachingAdvice(
                type: .organization,
                title: "Meeting Overload",
                description: "Meetings take \(Int(burnout.meetingOverloadRatio * 100))% of your active time. Consider async communication.",
                priority: .medium,
                actionItem: "Audit your recurring meetings — cancel or shorten where possible",
                category: "organization"
            ))
        }

        if deepWork.peakDeepWorkHours.count >= 2 {
            let hoursStr = deepWork.peakDeepWorkHours.sorted().map { "\($0):00" }.joined(separator: ", ")
            advice.append(CoachingAdvice(
                type: .productivity,
                title: "Peak Deep Work Hours Identified",
                description: "You're most productive at \(hoursStr). Protect these hours for focused work.",
                priority: .medium,
                actionItem: "Block \(hoursStr) for deep work every day",
                category: "productivity"
            ))
        }

        if burnout.averageWorkdayDuration > 57600 {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Long Workdays",
                description: "Your average workday is \(burnout.averageWorkdayDuration.formatDuration()). Aim for 8-hour days to maintain sustainable productivity.",
                priority: .medium,
                actionItem: "Set a daily quitting time and stick to it",
                category: "wellbeing"
            ))
        }

        if deepWork.sessionsToday.isEmpty && deepWork.totalDeepWorkToday < 600 {
            advice.append(CoachingAdvice(
                type: .focus,
                title: "No Deep Work Sessions Yet",
                description: "Start a focused work session to build momentum. Even 25 minutes helps.",
                priority: .low,
                actionItem: "Try a 25-minute Pomodoro session now",
                category: "focus"
            ))
        }

        if burnout.wellbeingTrend == .declining && burnout.wellbeingScore < 60 {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Declining Wellbeing Score",
                description: "Your wellbeing score dropped to \(Int(burnout.wellbeingScore))/100. Address burnout signals before they escalate.",
                priority: .high,
                actionItem: "Take a 30-minute break and review your workload balance",
                category: "wellbeing"
            ))
        }

        let prediction = await PredictiveInsightsService.shared.predictBurnoutRisk(daysAhead: 30)
        if prediction.predictedRiskLevel == .high || prediction.predictedRiskLevel == .critical {
            advice.append(CoachingAdvice(
                type: .wellbeing,
                title: "Burnout Predicted in 30 Days",
                description: "Based on your trends, burnout risk may reach \(prediction.predictedRiskLevel.rawValue) in 30 days (score: \(Int(prediction.predictedWellbeingScore))/100).",
                priority: .high,
                actionItem: "Review your weekly workload and add recovery time",
                category: "wellbeing"
            ))
        }

        let patterns = await PredictiveInsightsService.shared.getWeeklyPatterns()
        if let worstDay = patterns.min(by: { $0.avgWellbeingScore < $1.avgWellbeingScore }),
           worstDay.avgWellbeingScore < 65 {
            advice.append(CoachingAdvice(
                type: .organization,
                title: "Toughest Day: \(worstDay.dayName)",
                description: "\(worstDay.dayName) has your lowest wellbeing (\(Int(worstDay.avgWellbeingScore))/100). \(worstDay.insight).",
                priority: .medium,
                actionItem: "Reschedule non-essential meetings on \(worstDay.dayName)",
                category: "organization"
            ))
        }

        let useAI = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.useAIEnhancement) as? Bool ?? false
        if useAI {
            let enhanced = try? await enhanceAdviceWithAI(advice)
            return enhanced ?? advice
        }

        return advice.sorted { $0.priority.score > $1.priority.score }
    }

    // MARK: - AI-Enhanced Coaching

    private func enhanceAdviceWithAI(_ advice: [CoachingAdvice]) async throws -> [CoachingAdvice] {
        let provider: AIProvider
        let aiType = PrivacySettings.AIEnhancementType(
            rawValue: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.useAIType) ?? "Local AI Only"
        ) ?? .local

        switch aiType {
        case .local: provider = LocalAIProvider.shared
        case .remote, .both: provider = RemoteAIProvider.shared
        }

        let aiPrompt = AIPromptTemplates.coachingAdvice(advice: advice)
        let result = try await provider.generateSummary(systemPrompt: aiPrompt.system, userMessage: aiPrompt.user)

        var enhanced = advice
        if !result.isEmpty {
            let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
            for (index, line) in lines.enumerated() where index < enhanced.count {
                let parts = line.components(separatedBy: ": ")
                if parts.count >= 2 {
                    let old = enhanced[index]
                    enhanced[index] = CoachingAdvice(
                        id: old.id, type: old.type,
                        title: parts[0],
                        description: parts.dropFirst().joined(separator: ": "),
                        priority: old.priority,
                        actionItem: old.actionItem,
                        category: old.category,
                        timestamp: old.timestamp,
                        isRead: old.isRead,
                        isDismissed: old.isDismissed
                    )
                }
            }
        }
        return enhanced
    }

    // MARK: - Heatmap Data

    public func deepWorkHoursByDay(from startDate: Date, to endDate: Date) async -> [Date: TimeInterval] {
        let calendar = Calendar.current
        var result: [Date: TimeInterval] = [:]
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while current <= end {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            let range = current...nextDay
            if let records = try? await ActivityTracker.shared.records(in: range) {
                let productiveTypes: Set<ActivityType> = [.coding, .writing, .reading]
                let deepWorkTime = records.filter { productiveTypes.contains($0.activityType) }
                    .reduce(0) { $0 + $1.duration }
                if deepWorkTime > 0 {
                    result[current] = deepWorkTime
                }
            }
            current = nextDay
        }
        return result
    }

    // MARK: - Tracker State Aggregation

    public func getTrackerState() async -> TrackerState {
        let readingSession = await ReadingTracker.shared.currentSession
        let writingSession = await WritingTracker.shared.currentSession
        let emailSession = await EmailTracker.shared.currentSession
        let mediaTrack = await MediaTracker.shared.currentTrack
        let meetingSession = await MeetingTracker.shared.currentSession

        return TrackerState(
            isReadingActive: readingSession != nil,
            isWritingActive: writingSession != nil,
            isEmailActive: emailSession != nil,
            isMediaActive: mediaTrack?.isPlaying == true,
            isMeetingActive: meetingSession != nil,
            currentReadingTitle: readingSession?.title,
            currentWritingApp: writingSession?.appName,
            currentEmailSubject: emailSession?.subject,
            currentTrackInfo: mediaTrack.map { "\($0.artist) — \($0.title)" },
            currentMeetingTitle: meetingSession?.meetingTitle,
            lastUpdated: Date()
        )
    }

    // MARK: - Background Monitoring

    private func checkForRealtimeAdvice() async {
        let deepWork = await analyzeDeepWork(for: Date())
        let burnout = await detectBurnoutSignals(for: Date())
        let advice = await generateAdvice(deepWork: deepWork, burnout: burnout)

        let critical = advice.filter { $0.priority == .critical && !$0.isDismissed }
        for item in critical {
            Log.info("Coaching: \(item.title) — \(item.description)")
        }

        if !critical.isEmpty {
            recentAdvice = advice
        }
    }

    public func dismissAdvice(_ id: String) {
        if let index = recentAdvice.firstIndex(where: { $0.id == id }) {
            var updated = recentAdvice[index]
            updated.isDismissed = true
            recentAdvice[index] = updated
        }
    }

    public func markRead(_ id: String) {
        if let index = recentAdvice.firstIndex(where: { $0.id == id }) {
            var updated = recentAdvice[index]
            updated.isRead = true
            recentAdvice[index] = updated
        }
    }

    public var currentAdvice: [CoachingAdvice] {
        recentAdvice.filter { !$0.isDismissed }
    }

    // MARK: - Helpers

    private func buildSummary(deepWork: DeepWorkAnalysis, burnout: BurnoutSignals, advice: [CoachingAdvice]) -> String {
        let deepWorkHours = Int(deepWork.totalDeepWorkToday / 3600)
        let deepWorkMins = Int((deepWork.totalDeepWorkToday.truncatingRemainder(dividingBy: 3600)) / 60)

        var parts: [String] = [
            "Deep Work: \(deepWorkHours)h \(deepWorkMins)m (score: \(Int(deepWork.deepWorkScore))/100)"
        ]

        parts.append("Wellbeing: \(Int(burnout.wellbeingScore))/100 (\(burnout.wellbeingTrend.rawValue))")

        if burnout.riskLevel != .low {
            parts.append("⚠️ Burnout risk: \(burnout.riskLevel.rawValue)")
        }

        if !advice.isEmpty {
            let criticalCount = advice.filter { $0.priority == .critical || $0.priority == .high }.count
            parts.append("\(criticalCount) actionable recommendations")
        }

        return parts.joined(separator: " | ")
    }

    private func countContextSwitches(in records: [ActivityRecord]) -> Int {
        guard records.count >= 2 else { return 0 }
        let sorted = records.sorted { $0.timestamp < $1.timestamp }
        var switches = 0
        for i in 1..<sorted.count {
            if sorted[i].activityType != sorted[i - 1].activityType ||
               sorted[i].appName != sorted[i - 1].appName {
                switches += 1
            }
        }
        return switches
    }

    private func findPeakHours(from sessions: [DeepWorkSession]) -> [Int] {
        var hourCount: [Int: Int] = [:]
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourCount[hour, default: 0] += 1
        }
        let maxCount = hourCount.values.max() ?? 0
        guard maxCount > 0 else { return [] }
        return hourCount.filter { $0.value >= maxCount / 2 }.map(\.key).sorted()
    }

    private func calculateBurnoutRisk(overtimeHours: TimeInterval, nightWork: TimeInterval,
                                        weekendWork: TimeInterval, meetingOverload: Double,
                                        avgWorkday: TimeInterval) -> BurnoutRiskLevel {
        var riskScore = 0

        if overtimeHours > 14400 { riskScore += 3 }
        else if overtimeHours > 7200 { riskScore += 2 }
        else if overtimeHours > 3600 { riskScore += 1 }

        if nightWork > 21600 { riskScore += 3 }
        else if nightWork > 10800 { riskScore += 2 }
        else if nightWork > 3600 { riskScore += 1 }

        if weekendWork > 14400 { riskScore += 2 }
        else if weekendWork > 7200 { riskScore += 1 }

        if meetingOverload > 0.5 { riskScore += 2 }
        else if meetingOverload > 0.3 { riskScore += 1 }

        if avgWorkday > 72000 { riskScore += 2 }
        else if avgWorkday > 57600 { riskScore += 1 }

        switch riskScore {
        case 0...2: return .low
        case 3...5: return .moderate
        case 6...8: return .high
        default: return .critical
        }
    }

    private func calculateWellbeingScore(overtimeHours: TimeInterval, nightWork: TimeInterval,
                                          weekendWork: TimeInterval, meetingOverload: Double,
                                          contextSwitches: Double, avgWorkday: TimeInterval) -> Double {
        let overtimePenalty = min(overtimeHours / 14400, 1.0) * 100
        let nightWorkPenalty = min(nightWork / 21600, 1.0) * 100
        let weekendPenalty = min(weekendWork / 14400, 1.0) * 100
        let meetingPenalty = min(meetingOverload / 0.6, 1.0) * 100
        let switchesPenalty = min(contextSwitches / 20, 1.0) * 100
        let workdayPenalty = min(max(avgWorkday - 28800, 0) / 43200, 1.0) * 100

        let weightedPenalty =
            overtimePenalty * 0.20 +
            nightWorkPenalty * 0.20 +
            weekendPenalty * 0.15 +
            meetingPenalty * 0.15 +
            switchesPenalty * 0.10 +
            workdayPenalty * 0.20

        return max(0, min(100, 100 - weightedPenalty))
    }

    private func computePreviousWellbeingScore(for date: Date, calendar: Calendar) async -> Double {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return 100 }
        let dayStart = calendar.startOfDay(for: yesterday)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let records = try? await ActivityTracker.shared.records(in: dayStart...dayEnd) else { return 100 }

        let activeTime = records.reduce(0) { $0 + $1.duration }
        let isWorkHours = (9...18).contains(calendar.component(.hour, from: yesterday))
        let overtime = isWorkHours ? max(activeTime - 28800, 0) : activeTime

        var nightWork: TimeInterval = 0
        for record in records {
            let hour = calendar.component(.hour, from: record.timestamp)
            if hour < 7 || hour >= 22 { nightWork += record.duration }
        }

        let weekendWork = calendar.isDateInWeekend(yesterday) ? activeTime : 0
        let meetingDuration = records.filter { $0.activityType == .meeting }.reduce(0) { $0 + $1.duration }
        let meetingRatio = activeTime > 0 ? meetingDuration / activeTime : 0
        let switches = countContextSwitches(in: records)
        let switchesPerHour = activeTime > 0 ? Double(switches) / (activeTime / 3600) : 0

        return calculateWellbeingScore(
            overtimeHours: overtime, nightWork: nightWork, weekendWork: weekendWork,
            meetingOverload: meetingRatio, contextSwitches: switchesPerHour, avgWorkday: activeTime
        )
    }

}

extension AdvicePriority {
    var score: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}
