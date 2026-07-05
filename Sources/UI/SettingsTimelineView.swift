import SwiftUI

@MainActor
struct SettingsTimelineView: View {
    @State private var snapshots: [SettingsSnapshot] = []
    @State private var selectedSnapshot: SettingsSnapshot?
    @State private var diff: SettingsDiff?
    @State private var suggestion: String?
    @State private var isLoadingSuggestions = false
    @State private var showLabelSheet = false
    @State private var newLabel = ""
    @State private var showRollbackConfirm = false

    var body: some View {
        HSplitView {
            snapshotList
                .frame(minWidth: 200, idealWidth: 250)

            VStack {
                if let selected = selectedSnapshot {
                    snapshotDetail(selected)
                } else {
                    ContentUnavailableView(
                        "Select a snapshot",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Choose a snapshot from the list to view details, diff, or rollback.")
                    )
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minHeight: 300)
        .task { await loadSnapshots() }
        .sheet(isPresented: $showLabelSheet) {
            labelSheet
        }
        .alert("Rollback Settings?", isPresented: $showRollbackConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Rollback", role: .destructive) {
                if let snap = selectedSnapshot {
                    Task { await performRollback(snap) }
                }
            }
        } message: {
            Text("This will restore all settings to the values in the selected snapshot. A new snapshot of the current state will be saved first.")
        }
    }

    // MARK: - Snapshot List

    private var snapshotList: some View {
        List(selection: $selectedSnapshot) {
            Section("Timeline") {
                ForEach(snapshots) { snap in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.label ?? snap.source.rawValue.capitalized)
                            .fontWeight(.medium)
                        HStack {
                            Text(snap.timestamp, style: .date)
                            Text(verbatim: "·")
                            Text(snap.timestamp, style: .time)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .tag(snap)
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItemGroup {
                Button("Capture") {
                    showLabelSheet = true
                }
                .help("Capture current settings")

                Button("Suggest") {
                    Task { await loadSuggestion() }
                }
                .disabled(isLoadingSuggestions)
                .help("AI suggestion")
            }
        }
    }

    // MARK: - Detail

    private func snapshotDetail(_ snap: SettingsSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(snap.label ?? "Untitled")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(snap.timestamp, style: .date) \(snap.timestamp, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Label(snap.source.rawValue.capitalized, systemImage: sourceIcon(snap.source))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Rollback to This", role: .destructive) {
                            showRollbackConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                }

                Divider()

                if let diff = diff {
                    if diff.isEmpty {
                        Text("No changes from current settings")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Changes from current: \(diff.changeCount)")
                            .font(.headline)
                        diffSection("Changed", changes: diff.changed.map { (key: $0.key, old: $0.oldValue, new: $0.newValue) })
                        diffSection("Added", items: diff.added.map { "\($0.key): \($0.value)" })
                        diffSection("Removed", items: diff.removed.map { "\($0.key): \($0.value)" })
                    }
                } else {
                    ProgressView("Computing diff...")
                }

                if let settings = snap.decodedSettings {
                    Divider()
                    Text("All Settings")
                        .font(.headline)
                    ForEach(settings.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(val)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding()
        }
        .task(id: snapshots) {
            if let sel = selectedSnapshot {
                diff = await SettingsTimelineManager.shared.diffSince(sel)
            }
        }
    }

    private func diffSection(_ title: String, changes: [(key: String, old: String, new: String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            ForEach(changes, id: \.key) { change in
                VStack(alignment: .leading, spacing: 1) {
                    Text(change.key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(change.old)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .strikethrough()
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(change.new)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(6)
                .background(.fill.quaternary)
                .clipShape(.rect(cornerRadius: 4))
            }
        }
    }

    private func diffSection(_ title: String, items: [String]) -> some View {
        guard !items.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(title == "Added" ? .green : .red)
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .padding(4)
                        .background(.fill.quaternary)
                        .clipShape(.rect(cornerRadius: 4))
                }
            }
        )
    }

    // MARK: - Sheet

    private var labelSheet: some View {
        VStack(spacing: 16) {
            Text("Capture Settings Snapshot")
                .font(.headline)
            TextField("Label (optional)", text: $newLabel)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            HStack {
                Button("Cancel") {
                    showLabelSheet = false
                    newLabel = ""
                }
                Button("Capture") {
                    let label = newLabel.isEmpty ? nil : newLabel
                    Task {
                        await SettingsTimelineManager.shared.captureSnapshot(label: label)
                        await loadSnapshots()
                    }
                    showLabelSheet = false
                    newLabel = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }

    // MARK: - Actions

    private func loadSnapshots() async {
        snapshots = await SettingsTimelineManager.shared.snapshots()
    }

    private func performRollback(_ snap: SettingsSnapshot) async {
        _ = await SettingsTimelineManager.shared.rollback(to: snap)
        await loadSnapshots()
    }

    private func loadSuggestion() async {
        isLoadingSuggestions = true
        suggestion = await SettingsTimelineManager.shared.suggestChanges()
        isLoadingSuggestions = false
    }

    private func sourceIcon(_ source: SnapshotSource) -> String {
        switch source {
        case .manual: return "hand.tap"
        case .automatic: return "clock"
        case .aiSuggestion: return "sparkles"
        case .rollback: return "arrow.uturn.backward"
        }
    }
}
