import SwiftUI
import AppKit

@MainActor
struct DeepWorkHeatmapView: View {
    @State private var deepWorkData: [Date: TimeInterval] = [:]
    @State private var selectedDate: Date?
    @State private var isLoading = false

    private let coachingService = CoachingService.shared
    private let calendar = Calendar.current
    private let weekDays: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var dateRange: (start: Date, end: Date) {
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -83, to: end) else { return (end, end) }
        return (start, end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
                Text(L10n.deepWork.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(L10n.peakHours.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                legend
            }

            ScrollView(.horizontal, showsIndicators: false) {
                heatmapGrid
                    .padding(.vertical, 4)
            }

            if let date = selectedDate, let hours = deepWorkData[date] {
                HStack {
                    Circle()
                        .fill(color(for: hours))
                        .frame(width: 8, height: 8)
                    Text("\(date.formatted(date: .abbreviated, time: .omitted)) — \(formatDuration(hours))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.fill.quinary)
                .clipShape(.rect(cornerRadius: 4))
            }
        }
        .padding()
        .background(.fill.quinary)
        .clipShape(.rect(cornerRadius: 8))
        .task {
            await loadData()
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(self.legendColor(level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var heatmapGrid: some View {
        let (start, end) = dateRange
        let weeks = weeksInRange(start: start, end: end)

        return VStack(alignment: .leading, spacing: 2) {
            monthLabels(for: weeks)

            HStack(alignment: .top, spacing: 2) {
                dayLabels

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        HStack(spacing: 2) {
                            ForEach(weeks.indices, id: \.self) { weekIndex in
                                let date = dateFor(weekIndex: weekIndex, dayIndex: dayIndex, start: start)
                                if let date, date <= end {
                                    cell(for: date)
                                } else {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var dayLabels: some View {
        VStack(spacing: 2) {
            ForEach(weekDays.indices, id: \.self) { index in
                Text(weekDays[index])
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.trailing, 4)
    }

    private func monthLabels(for weeks: [Date]) -> some View {
        HStack(spacing: 2) {
            Text("")
                .frame(width: 18)
            ForEach(weeks.indices, id: \.self) { index in
                let date = weeks[index]
                let month = calendar.component(.month, from: date)
                let prevMonth: Int = {
                    guard index > 0 else { return 0 }
                    return calendar.component(.month, from: weeks[index - 1])
                }()
                if month != prevMonth {
                    Text(date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .leading)
                } else {
                    Text("")
                        .frame(width: 14)
                }
            }
        }
    }

    private func cell(for date: Date) -> some View {
        let hours = deepWorkData[date] ?? 0
        return Button {
            selectedDate = (selectedDate == date) ? nil : date
        } label: {
            Rectangle()
                .fill(color(for: hours))
                .frame(width: 14, height: 14)
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(formatDuration(hours)) of deep work")
    }

    private func color(for hours: TimeInterval) -> Color {
        switch hours {
        case 0: return Color(nsColor: .quaternaryLabelColor)
        case ..<1800: return .green.opacity(0.3)
        case ..<3600: return .green.opacity(0.5)
        case ..<7200: return .green.opacity(0.7)
        default: return .green.opacity(0.9)
        }
    }

    private func legendColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color(nsColor: .quaternaryLabelColor)
        case 1: return .green.opacity(0.3)
        case 2: return .green.opacity(0.5)
        case 3: return .green.opacity(0.7)
        case 4: return .green.opacity(0.9)
        default: return Color(nsColor: .quaternaryLabelColor)
        }
    }

    private func weeksInRange(start: Date, end: Date) -> [Date] {
        var weeks: [Date] = []
        var current = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start))!
        while current <= end {
            weeks.append(current)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }
        return weeks
    }

    private func dateFor(weekIndex: Int, dayIndex: Int, start: Date) -> Date? {
        let weekday = calendar.component(.weekday, from: start)
        let startSunday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start))!
        let offset = dayIndex + 1 - (weekday == 1 ? 0 : weekday - 1)
        return calendar.date(byAdding: .day, value: weekIndex * 7 + offset, to: startSunday)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func loadData() async {
        isLoading = true
        let (start, end) = dateRange
        deepWorkData = await coachingService.deepWorkHoursByDay(from: start, to: end)
        isLoading = false
    }
}
