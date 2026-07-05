import SwiftUI
import AppKit

struct KPICard: View {
    let icon: String
    let label: String
    let value: String
    let trend: WellbeingTrend?
    let color: Color
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let trend {
                    trendIcon(for: trend)
                        .foregroundStyle(trendColor(trend))
                        .font(.caption2)
                }
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .contentTransition(.numericText())

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.fill.quinary)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func trendIcon(for trend: WellbeingTrend) -> some View {
        switch trend {
        case .improving:
            Image(systemName: "arrow.up.right")
        case .stable:
            Image(systemName: "arrow.right")
        case .declining:
            Image(systemName: "arrow.down.right")
        }
    }

    private func trendColor(_ trend: WellbeingTrend) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .secondary
        case .declining: return .red
        }
    }
}

#Preview {
    HStack {
        KPICard(icon: "brain.head.profile", label: "Deep Work", value: "78/100", trend: .improving, color: .blue, detail: "3 sessions today")
        KPICard(icon: "heart.fill", label: "Wellbeing", value: "85/100", trend: .stable, color: .green)
        KPICard(icon: "eye.fill", label: "Trackers", value: "3 active", trend: nil, color: .orange)
    }
    .padding()
    .frame(width: 400)
}
