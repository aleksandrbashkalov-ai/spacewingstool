import SwiftUI

@MainActor
struct ContextIndicatorView: View {
    @Environment(SpaceStore.self) private var spaceStore

    var body: some View {
        HStack(spacing: 12) {
            productivityBadge
            timeBadge
            appCountBadge
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(contextAccessibilityLabel)
    }

    private var productivityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color(for: spaceStore.currentContext?.productivityEstimate ?? .neutral))
                .frame(width: 8, height: 8)
            Text(spaceStore.currentContext?.productivityEstimate.rawValue ?? "Idle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: spaceStore.currentContext?.timeOfDay.symbolName ?? "sun.max")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(spaceStore.currentContext?.timeOfDay.rawValue ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "app")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(spaceStore.currentContext?.activeApps.count ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for level: ProductivityLevel) -> Color {
        switch level {
        case .focused: return .green
        case .neutral: return .yellow
        case .distracted: return .red
        case .idle: return .gray
        }
    }

    private var contextAccessibilityLabel: String {
        guard let ctx = spaceStore.currentContext else { return "No context data" }
        return "Productivity: \(ctx.productivityEstimate.rawValue), Time: \(ctx.timeOfDay.rawValue), \(ctx.activeApps.count) apps active"
    }
}
