import SwiftUI

@MainActor
struct SpaceListView: View {
    @Environment(SpaceStore.self) private var spaceStore
    @State private var showingAddSheet = false
    @State private var searchText = ""

    private var filteredSpaces: [Space] {
        guard !searchText.isEmpty else { return spaceStore.spaces }
        return spaceStore.spaces.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            spaceList
            addButton
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSpaceView()
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search spaces", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 8))
        .padding(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search spaces")
    }

    private var spaceList: some View {
        List(filteredSpaces) { space in
            SpaceRowView(space: space)
                .contextMenu {
                    Button {
                        spaceStore.activateSpace(space)
                    } label: {
                        Label("Activate", systemImage: "play")
                    }
                    Button {
                        spaceStore.toggleFavorite(space)
                    } label: {
                        Label(space.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: space.isFavorite ? "star.slash" : "star")
                    }
                    Divider()
                    Button(role: .destructive) {
                        spaceStore.removeSpace(space)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        spaceStore.removeSpace(space)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        spaceStore.toggleFavorite(space)
                    } label: {
                        Label("Favorite", systemImage: "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        spaceStore.activateSpace(space)
                    } label: {
                        Label("Activate", systemImage: "play.fill")
                    }
                    .tint(.green)
                }
        }
        .listStyle(.inset)
    }

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Label("New Space", systemImage: "plus")
                .frame(maxWidth: .infinity)
                .padding(8)
        }
        .buttonStyle(.borderedProminent)
        .padding(8)
    }
}

@MainActor
struct SpaceRowView: View {
    let space: Space

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: space.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(space.name)
                        .fontWeight(.medium)
                    if space.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                }
                if !space.triggers.isEmpty {
                    Text(triggerSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if space.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Active")
            }

            Text(space.mode.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.fill.quaternary)
                .clipShape(.rect(cornerRadius: 4))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(space.name), \(space.mode.rawValue)")
        .accessibilityValue(space.isActive ? "Active" : "Inactive")
    }

    private var triggerSummary: String {
        space.triggers.map { trigger in
            switch trigger {
            case .appRunning(let ids): return "Apps: \(ids.count)"
            case .timeRange: return "Scheduled"
            case .calendarEvent: return "Calendar"
            case .focusMode(let name): return "Focus: \(name)"
            case .urlPattern: return "URL match"
            case .manual: return "Manual"
            }
        }.joined(separator: ", ")
    }
}

@MainActor
struct AddSpaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceStore.self) private var spaceStore
    @State private var name = ""
    @State private var mode: SpaceMode = .custom
    @State private var selectedIcon = "square.split.2x2"

    private let icons = ["square.split.2x2", "brain.head.profile", "chevron.left.forwardslash.chevron.right",
                         "video", "paintbrush.pointed", "globe", "book", "music.note", "person.2"]

    private let iconColumns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        VStack(spacing: 16) {
            headerView
            TextField("Space Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Space name")
            modePicker
            iconPicker
            actionButtons
        }
        .padding()
        .frame(width: 320)
        .fixedSize()
    }

    private var headerView: some View {
        Text("New Space")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(SpaceMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.radioGroup)
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            iconLabel
            iconGrid
        }
    }

    private var iconLabel: some View {
        Text("Icon")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var iconGrid: some View {
        LazyVGrid(columns: iconColumns, spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                iconCell(icon)
            }
        }
    }

    private func iconCell(_ icon: String) -> some View {
        Button {
            selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(selectedIcon == icon ? .white : .primary)
                .frame(width: 36, height: 36)
                .background {
                    if selectedIcon == icon {
                        Color.accentColor
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(.fill.quaternary)
                    }
                }
                .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Icon \(icon)")
        .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Create") {
                spaceStore.addSpace(name: name, mode: mode)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
    }
}
