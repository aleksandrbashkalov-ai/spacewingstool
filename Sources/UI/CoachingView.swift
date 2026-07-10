import SwiftUI

@MainActor
struct CoachingView: View {
    @Environment(SettingsStore.self) private var settings

    @State private var coachingReport: CoachingReport?
    @State private var adviceItems: [CoachingAdvice] = []
    @State private var deepWorkAnalysis = DeepWorkAnalysis()
    @State private var burnoutSignals = BurnoutSignals()
    @State private var isGenerating = false
    @State private var selectedAdvice: CoachingAdvice?

    private let coachingService = CoachingService.shared

    var body: some View {
        HSplitView {
            adviceListSection
                .frame(minWidth: 250)

            if let selected = selectedAdvice {
                adviceDetailSection(selected)
                    .frame(minWidth: 200)
            } else {
                coachingSummarySection
                    .frame(minWidth: 200)
            }
        }
        .task {
            await loadData()
        }
    }

    private var adviceListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundStyle(.tint)
                    Text(L10n.productivityCoach.localized)
                        .font(.headline)
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(L10n.refresh.localized) {
                            Task { await loadData() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)

                Text(L10n.recommendationsCount.localized(adviceItems.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if adviceItems.isEmpty {
                    ContentUnavailableView(
                        L10n.noRecommendations.localized,
                        systemImage: "checkmark.circle",
                        description: Text(L10n.healthyPatterns.localized)
                    )
                    .padding()
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(adviceItems) { advice in
                            Button {
                                selectedAdvice = advice
                                Task { await coachingService.markRead(advice.id) }
                            } label: {
                                AdviceCard(advice: advice)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                    Button(advice.isDismissed ? L10n.show.localized : L10n.dismiss.localized) {
                                        if advice.isDismissed {
                                            selectedAdvice = nil
                                        } else {
                                            Task { await coachingService.dismissAdvice(advice.id) }
                                            Task { @MainActor in adviceItems = await coachingService.currentAdvice }
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var coachingSummarySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let report = coachingReport {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.todaysCoachingReport.localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(report.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.fill.quinary)
                    .clipShape(.rect(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.tint)
                        Text(L10n.deepWork.localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    metricRow(L10n.score.localized, "\(Int(deepWorkAnalysis.deepWorkScore))/100")
                    metricRow(L10n.totalToday.localized, deepWorkAnalysis.totalDeepWorkToday.formatDuration())
                    metricRow(L10n.sessions.localized, "\(deepWorkAnalysis.sessionsToday.count)")
                    metricRow(L10n.peakHours.localized, deepWorkAnalysis.peakDeepWorkHours.sorted().map { "\($0):00" }.joined(separator: ", "))
                }
                .padding()
                .background(.fill.quinary)
                .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: burnoutSignals.riskLevel == .low ? "face.smiling" : "exclamationmark.triangle")
                            .foregroundStyle(Color.burnoutColor(burnoutSignals.riskLevel))
                        Text(L10n.wellbeing.localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(burnoutSignals.riskLevel.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.burnoutColor(burnoutSignals.riskLevel).opacity(0.2))
                            .clipShape(.rect(cornerRadius: 4))
                    }
                    metricRow(L10n.overtimeToday.localized, burnoutSignals.overtimeHoursToday.formatDuration())
                    metricRow(L10n.nightWorkWeek.localized, burnoutSignals.nightWorkHoursThisWeek.formatDuration())
                    metricRow(L10n.meetingOverload.localized, "\(Int(burnoutSignals.meetingOverloadRatio * 100))%")
                    metricRow(L10n.avgWorkday.localized, burnoutSignals.averageWorkdayDuration.formatDuration())
                }
                .padding()
                .background(.fill.quinary)
                .clipShape(.rect(cornerRadius: 8))
            }
            .padding()
        }
    }

    private func adviceDetailSection(_ advice: CoachingAdvice) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: adviceIcon(advice.type))
                    .foregroundStyle(Color.priorityColor(advice.priority))
                VStack(alignment: .leading) {
                    Text(advice.title)
                        .font(.headline)
                    Text(advice.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                priorityBadge(advice.priority)
            }

            Text(advice.description)
                .font(.body)
                .foregroundStyle(.secondary)

            if let action = advice.actionItem {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.suggestedAction.localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.tint)
                        Text(action)
                            .font(.body)
                    }
                }
            }

            Spacer()

            HStack {
                Text(L10n.detected.localized(advice.timestamp.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.dismiss.localized) {
                    Task { await coachingService.dismissAdvice(advice.id) }
                    Task { @MainActor in adviceItems = await coachingService.currentAdvice; selectedAdvice = nil }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }

    private func loadData() async {
        isGenerating = true
        adviceItems = await coachingService.generateRealtimeAdvice()
        let report = await coachingService.generateDailyReport(for: Date())
        coachingReport = report
        deepWorkAnalysis = report.deepWorkAnalysis
        burnoutSignals = report.burnoutSignals
        isGenerating = false
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
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

    private func priorityBadge(_ priority: AdvicePriority) -> some View {
        Text(priority.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
                    .background(Color.priorityColor(priority).opacity(0.2))
            .foregroundStyle(Color.priorityColor(priority))
            .clipShape(.rect(cornerRadius: 4))
    }

    private func adviceIcon(_ type: AdviceType) -> String {
        switch type {
        case .productivity: return "chart.line.uptrend.xyaxis"
        case .focus: return "scope"
        case .wellbeing: return "heart.fill"
        case .organization: return "square.grid.2x2"
        case .learning: return "book.fill"
        }
    }

}

@MainActor
private struct AdviceCard: View {
    let advice: CoachingAdvice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(advice.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(advice.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if advice.isDismissed {
                Image(systemName: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.fill.quinary)
        .clipShape(.rect(cornerRadius: 6))
        .opacity(advice.isDismissed ? 0.5 : 1)
    }

    private var icon: String {
        switch advice.type {
        case .productivity: return "chart.line.uptrend.xyaxis"
        case .focus: return "scope"
        case .wellbeing: return "heart.fill"
        case .organization: return "square.grid.2x2"
        case .learning: return "book.fill"
        }
    }

    private var color: Color {
        switch advice.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}
