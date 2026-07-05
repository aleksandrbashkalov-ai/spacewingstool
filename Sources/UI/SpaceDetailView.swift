import SwiftUI

@MainActor
struct SpaceDetailView: View {
    let space: Space
    @Environment(SpaceStore.self) private var spaceStore
    @State private var showingEditTriggers = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                    .accessibilityAddTraits(.isHeader)
                Divider()
                triggersSection
                Divider()
                appsSection
                Divider()
                actionsSection
            }
            .padding()
        }
        .sheet(isPresented: $showingEditTriggers) {
            TriggerEditorView(space: space)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: space.iconName)
                .font(.system(size: 36))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(space.name)
                    .font(.title)
                    .fontWeight(.bold)
                Text(space.mode.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let lastUsed = space.lastUsedAt {
                    Text("Last used: \(lastUsed.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if space.isActive {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.gradient)
                    .clipShape(.rect(cornerRadius: 6))
                    .accessibilityLabel("Active space")
            }
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Triggers", systemImage: "bell")
                    .font(.headline)
                Spacer()
                Button("Edit") { showingEditTriggers = true }
                    .controlSize(.small)
            }

            if space.triggers.isEmpty {
                ContentUnavailableView(
                    "No Triggers",
                    systemImage: "bell.slash",
                    description: Text("Add triggers to automatically activate this space.")
                )
            } else {
                ForEach(Array(space.triggers.enumerated()), id: \.offset) { _, trigger in
                    triggerRow(trigger)
                }
            }
        }
    }

    private func triggerRow(_ trigger: SpaceTrigger) -> some View {
        HStack {
            Image(systemName: triggerIcon(trigger))
                .foregroundStyle(.tint)
            Text(triggerDescription(trigger))
                .font(.subheadline)
            Spacer()
        }
        .padding(8)
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trigger: \(triggerDescription(trigger))")
    }

    private func triggerIcon(_ trigger: SpaceTrigger) -> String {
        switch trigger {
        case .appRunning: return "app.badge"
        case .urlPattern: return "link"
        case .timeRange: return "clock"
        case .calendarEvent: return "calendar"
        case .focusMode: return "moon"
        case .manual: return "hand.tap"
        }
    }

    private func triggerDescription(_ trigger: SpaceTrigger) -> String {
        switch trigger {
        case .appRunning(let ids): return "When running: \(ids.joined(separator: ", "))"
        case .urlPattern(let pattern): return "URL matches: \(pattern)"
        case .timeRange(let start, let end): return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case .calendarEvent(let keywords): return "Calendar events: \(keywords.joined(separator: ", "))"
        case .focusMode(let name): return "Focus mode: \(name)"
        case .manual: return "Manual activation"
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Saved Layout (\(space.appLayouts.count) apps)",
                  systemImage: "rectangle.3.group")
                .font(.headline)

            if space.appLayouts.isEmpty {
                ContentUnavailableView(
                    "No Layout Saved",
                    systemImage: "square.dashed",
                    description: Text("Capture the current window layout to restore it later.")
                )
            } else {
                ForEach(Array(space.appLayouts.prefix(5).enumerated()), id: \.offset) { _, layout in
                    HStack {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                        Text(layout.bundleID)
                            .font(.caption)
                        Spacer()
                        if layout.isFrontmost {
                            Text("Frontmost")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(4)
                }
                if space.appLayouts.count > 5 {
                    Text("+\(space.appLayouts.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    spaceStore.activateSpace(space)
                }
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
            } label: {
                Label("Activate", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                var mutable = space
                spaceStore.snapshotCurrentLayout(for: &mutable)
                spaceStore.updateSpace(mutable)
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .levelChange,
                    performanceTime: .default
                )
            } label: {
                Label("Capture Layout", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

@MainActor
struct TriggerEditorView: View {
    let space: Space
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceStore.self) private var spaceStore
    @State private var triggers: [SpaceTrigger]
    @State private var showingAddTriggerPicker = false

    init(space: Space) {
        self.space = space
        _triggers = State(initialValue: space.triggers)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Triggers")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if triggers.isEmpty {
                ContentUnavailableView(
                    "No Triggers",
                    systemImage: "bell.slash",
                    description: Text("Add a trigger to automatically activate this space.")
                )
            } else {
                List {
                    ForEach(Array(triggers.enumerated()), id: \.offset) { index, trigger in
                        HStack {
                            Image(systemName: triggerIcon(trigger))
                                .foregroundStyle(.tint)
                            Text(triggerDescription(trigger))
                                .font(.subheadline)
                            Spacer()
                            Button(role: .destructive) {
                                triggers.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .help("Remove trigger")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Trigger: \(triggerDescription(trigger))")
                    }
                    .onDelete { indexSet in
                        triggers.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.inset)
            }

            Menu("Add Trigger") {
                Button("App Running") {
                    triggers.append(.appRunning(bundleIDs: []))
                }
                Button("URL Pattern") {
                    triggers.append(.urlPattern(pattern: ""))
                }
                Button("Time Range") {
                    let now = Date()
                    triggers.append(.timeRange(start: now, end: now.addingTimeInterval(3600)))
                }
                Button("Calendar Event") {
                    triggers.append(.calendarEvent(keywords: []))
                }
                Button("Focus Mode") {
                    triggers.append(.focusMode(name: ""))
                }
                Button("Manual") {
                    triggers.append(.manual)
                }
            }
            .fixedSize()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    if let idx = spaceStore.spaces.firstIndex(where: { $0.id == space.id }) {
                        var updated = spaceStore.spaces[idx]
                        updated.triggers = triggers
                        spaceStore.updateSpace(updated)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450, height: 400)
        .fixedSize()
    }

    private func triggerIcon(_ trigger: SpaceTrigger) -> String {
        switch trigger {
        case .appRunning: return "app.badge"
        case .urlPattern: return "link"
        case .timeRange: return "clock"
        case .calendarEvent: return "calendar"
        case .focusMode: return "moon"
        case .manual: return "hand.tap"
        }
    }

    private func triggerDescription(_ trigger: SpaceTrigger) -> String {
        switch trigger {
        case .appRunning(let ids): return "Apps: \(ids.joined(separator: ", "))"
        case .urlPattern(let pattern): return "URL: \(pattern.isEmpty ? "(enter pattern)" : pattern)"
        case .timeRange(let start, let end): return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case .calendarEvent(let keywords): return "Calendar: \(keywords.joined(separator: ", "))"
        case .focusMode(let name): return "Focus: \(name.isEmpty ? "(enter name)" : name)"
        case .manual: return "Manual"
        }
    }
}
