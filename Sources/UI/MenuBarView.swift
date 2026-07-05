import SwiftUI

@MainActor
struct MenuBarView: View {
    @Environment(SpaceStore.self) private var spaceStore
    @Environment(SettingsStore.self) private var settingsStore

    @State private var deepWorkScore: Double = 0
    @State private var wellbeingScore: Double = 100
    @State private var wellbeingTrend: WellbeingTrend = .stable
    @State private var activeTrackers: Int = 0
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            kpiSection
            Divider()
            contextSection
            Divider()
            spacesSection
            Divider()
            bottomSection
        }
        .localeAware(LocalizationManager.shared.currentLanguage)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .task {
            await refreshKPI()
            refreshTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    await refreshKPI()
                }
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "square.split.2x2")
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: spaceStore.activeSpace?.id)
            Text(Constants.appName)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var kpiSection: some View {
        HStack(spacing: 6) {
            KPICard(
                icon: "brain.head.profile",
                label: L10n.deepWork.localized,
                value: "\(Int(deepWorkScore))/100",
                trend: nil,
                color: .blue,
                detail: nil
            )
            .frame(maxWidth: .infinity)

            KPICard(
                icon: "heart.fill",
                label: L10n.wellbeing.localized,
                value: "\(Int(wellbeingScore))/100",
                trend: wellbeingTrend,
                color: wellbeingScore >= 70 ? .green : .orange,
                detail: nil
            )
            .frame(maxWidth: .infinity)

            KPICard(
                icon: "eye.fill",
                label: L10n.monitor.localized,
                value: "\(activeTrackers) \(L10n.active.localized.lowercased())",
                trend: nil,
                color: .orange,
                detail: nil
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var contextSection: some View {
        if let ctx = spaceStore.currentContext {
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(productivityColor(ctx.productivityEstimate))
                        .frame(width: 6, height: 6)
                        .accessibilityLabel(L10n.productivity.localized(ctx.productivityEstimate.rawValue))
                    Text(ctx.productivityEstimate.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "·")
                        .foregroundStyle(.secondary)
                    Text(ctx.timeOfDay.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                HStack {
                    Text(L10n.appCount.localized(ctx.activeApps.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }

        if let suggested = spaceStore.suggestedSpace {
            HStack {
                Image(systemName: suggested.iconName)
                    .foregroundStyle(.tint)
                Text(L10n.switchTo.localized(suggested.name))
                    .font(.caption)
                Spacer()
                Button(L10n.switch.localized) { spaceStore.activateSpace(suggested) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button {
                    spaceStore.suggestedSpace = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.tint.opacity(0.1))
            .clipShape(.rect(cornerRadius: 6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var spacesSection: some View {
        Group {
            if let active = spaceStore.activeSpace {
                HStack {
                    Image(systemName: active.iconName)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(active.name)
                            .fontWeight(.semibold)
                        Text(L10n.activeSpace.localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            ForEach(spaceStore.spaces.filter { $0.id != spaceStore.activeSpace?.id }) { space in
                Button {
                    spaceStore.activateSpace(space)
                } label: {
                    HStack {
                        Image(systemName: space.iconName)
                            .foregroundStyle(.tint)
                            .frame(width: 20)
                        Text(space.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if space.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomSection: some View {
        VStack(spacing: 2) {
            Button {
                spaceStore.addSpace(name: L10n.newSpace.localized)
            } label: {
                Label(L10n.newSpace.localized, systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Toggle(isOn: Bindable(settingsStore).isAutoSwitchEnabled) {
                Label(L10n.autoSwitch.localized, systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            SettingsLink {
                Label(L10n.settings.localized, systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(L10n.quit.localized, systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func productivityColor(_ level: ProductivityLevel) -> Color {
        switch level {
        case .focused: return .green
        case .neutral: return .yellow
        case .distracted: return .red
        case .idle: return .gray
        }
    }

    private func refreshKPI() async {
        let coaching = CoachingService.shared
        let trackerState = await coaching.getTrackerState()
        activeTrackers = [trackerState.isReadingActive, trackerState.isWritingActive,
                          trackerState.isEmailActive, trackerState.isMediaActive,
                          trackerState.isMeetingActive].filter { $0 }.count
        let burnout = await coaching.detectBurnoutSignals(for: Date())
        wellbeingScore = burnout.wellbeingScore
        wellbeingTrend = burnout.wellbeingTrend
        let deepWork = await coaching.analyzeDeepWork(for: Date())
        deepWorkScore = deepWork.deepWorkScore
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
