import SwiftUI

@MainActor
struct TransparencyDashboardView: View {
    @Environment(SettingsStore.self) private var settings

    @State private var trackerState = TrackerState()
    @State private var deepWorkAnalysis = DeepWorkAnalysis()
    @State private var burnoutSignals = BurnoutSignals()
    @State private var refreshTimer: Task<Void, Never>?

    private let coachingService = CoachingService.shared
    private let privacySettings: [String: (Bool, String)] = [
        "Reading": (true, "privacy_trackReading"),
        "Writing": (true, "privacy_trackWriting"),
        "Email": (true, "privacy_trackEmail"),
        "Media": (true, "privacy_trackMedia"),
        "Meetings": (true, "privacy_trackMeetings"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                Divider()
                liveMonitoringSection
                Divider()
                deepWorkSection
                Divider()
                burnoutSection
                Divider()
                DeepWorkHeatmapView()
            }
            .padding()
        }
        .task {
            await refresh()
            refreshTimer = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    await refresh()
                }
            }
        }
        .onDisappear {
            refreshTimer?.cancel()
            refreshTimer = nil
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "eye.fill")
                .foregroundStyle(.tint)
            Text(L10n.transparencyDashboard.localized)
                .font(.headline)
            Spacer()
            Text(L10n.liveMonitoring.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        }
    }

    private var liveMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.currentlyMonitored.localized)
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                trackerCard(
                    title: L10n.readingTracking.localized,
                    icon: "book.fill",
                    isActive: trackerState.isReadingActive,
                    detail: trackerState.currentReadingTitle ?? L10n.noActiveSession.localized,
                    enabled: settings.trackReading
                )
                trackerCard(
                    title: L10n.writingTracking.localized,
                    icon: "pencil.tip",
                    isActive: trackerState.isWritingActive,
                    detail: trackerState.currentWritingApp ?? L10n.noActiveSession.localized,
                    enabled: settings.trackWriting
                )
                trackerCard(
                    title: L10n.emailTracking.localized,
                    icon: "envelope.fill",
                    isActive: trackerState.isEmailActive,
                    detail: trackerState.currentEmailSubject ?? L10n.noActiveSession.localized,
                    enabled: settings.trackEmail
                )
                trackerCard(
                    title: L10n.mediaTracking.localized,
                    icon: "music.note",
                    isActive: trackerState.isMediaActive,
                    detail: trackerState.currentTrackInfo ?? L10n.noMediaPlaying.localized,
                    enabled: settings.trackMedia
                )
                trackerCard(
                    title: L10n.meetingTracking.localized,
                    icon: "video.fill",
                    isActive: trackerState.isMeetingActive,
                    detail: trackerState.currentMeetingTitle ?? L10n.noActiveMeeting.localized,
                    enabled: settings.trackMeetings
                )
            }
        }
    }

    private var deepWorkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.tint)
                Text(L10n.deepWorkAnalysis.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            deepWorkRow(label: L10n.score.localized, value: "\(Int(deepWorkAnalysis.deepWorkScore))/100")
            deepWorkRow(label: L10n.totalToday.localized, value: formatDuration(deepWorkAnalysis.totalDeepWorkToday))
            deepWorkRow(label: L10n.sessions.localized, value: "\(deepWorkAnalysis.sessionsToday.count)")
            deepWorkRow(label: L10n.longestSession.localized, value: formatDuration(deepWorkAnalysis.longestSessionToday))
            deepWorkRow(label: L10n.contextSwitchesPerHour.localized, value: String(format: "%.1f", deepWorkAnalysis.contextSwitchesPerHour))

            if !deepWorkAnalysis.peakDeepWorkHours.isEmpty {
                let hoursStr = deepWorkAnalysis.peakDeepWorkHours.sorted().map { "\($0):00" }.joined(separator: ", ")
                deepWorkRow(label: L10n.peakHours.localized, value: hoursStr)
            }
        }
        .padding()
        .background(.fill.quinary)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var burnoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: burnoutSignals.riskLevel == .low ? "face.smiling" : "exclamationmark.triangle")
                    .foregroundStyle(burnoutColor(burnoutSignals.riskLevel))
                Text(L10n.burnoutSignals.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(burnoutSignals.riskLevel.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(burnoutColor(burnoutSignals.riskLevel).opacity(0.2))
                    .clipShape(.rect(cornerRadius: 4))
            }

            burnoutRow(label: L10n.riskLevel.localized, value: burnoutSignals.riskLevel.rawValue)
            burnoutRow(label: L10n.overtimeToday.localized, value: formatDuration(burnoutSignals.overtimeHoursToday))
            burnoutRow(label: L10n.nightWorkWeek.localized, value: formatDuration(burnoutSignals.nightWorkHoursThisWeek))
            burnoutRow(label: L10n.weekendWorkWeek.localized, value: formatDuration(burnoutSignals.weekendWorkHoursThisWeek))
            burnoutRow(label: L10n.meetingOverload.localized, value: "\(Int(burnoutSignals.meetingOverloadRatio * 100))%")
            burnoutRow(label: L10n.avgWorkday.localized, value: formatDuration(burnoutSignals.averageWorkdayDuration))
        }
        .padding()
        .background(.fill.quinary)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func trackerCard(title: String, icon: String, isActive: Bool, detail: String, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(isActive ? .green : .secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                if !enabled {
                    Text(L10n.disabled.localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if isActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(.fill.quinary)
        .clipShape(.rect(cornerRadius: 6))
    }

    private func deepWorkRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func burnoutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func burnoutColor(_ level: BurnoutRiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func refresh() async {
        trackerState = await coachingService.getTrackerState()
        deepWorkAnalysis = await coachingService.analyzeDeepWork(for: Date())
        burnoutSignals = await coachingService.detectBurnoutSignals(for: Date())
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

#Preview {
    TransparencyDashboardView()
        .environment(SettingsStore.shared)
}
