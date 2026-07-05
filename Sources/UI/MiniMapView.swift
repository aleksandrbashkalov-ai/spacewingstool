import SwiftUI

@MainActor
struct MiniMapView: View {
    @Environment(SpaceStore.self) private var spaceStore
    @Environment(SettingsStore.self) private var settingsStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 2)

    var body: some View {
        VStack(spacing: 8) {
            headerSection

            if spaceStore.spaces.isEmpty {
                emptyState
            } else {
                spacesGrid
            }
        }
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.windowBackground)
                .shadow(color: .black.opacity(0.15), radius: 8)
        }
        .frame(width: 280, height: 400)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spaces minimap")
    }

    private var headerSection: some View {
        HStack {
            Label("Spaces", systemImage: "square.split.2x2")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if settingsStore.isAutoSwitchEnabled {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
                    .accessibilityLabel("Auto-switch enabled")
            }
        }
        .padding(.horizontal, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "square.split.2x2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No spaces yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var spacesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(spaceStore.spaces) { space in
                    SpaceCellView(space: space)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                spaceStore.activateSpace(space)
                            }
                        }
                        .accessibilityLabel("\(space.name) space")
                        .accessibilityAddTraits(space.isActive ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8)
        }

        if let suggested = spaceStore.suggestedSpace {
            suggestedSpaceBar(suggested)
        }
    }

    private func suggestedSpaceBar(_ space: Space) -> some View {
        HStack {
            Image(systemName: space.iconName)
                .foregroundStyle(.tint)
            Text("\"\(space.name)\"")
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
            Button("Switch") {
                spaceStore.activateSpace(space)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.tint.opacity(0.1))
        .clipShape(.rect(cornerRadius: 6))
        .padding(.horizontal, 4)
        .accessibilityLabel("Suggested space: \(space.name)")
    }
}

@MainActor
struct SpaceCellView: View {
    let space: Space
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: space.iconName)
                .font(.title3)
                .foregroundStyle(space.isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))

            Text(space.name)
                .font(.caption2)
                .fontWeight(space.isActive ? .bold : .regular)
                .foregroundStyle(space.isActive ? .white : .primary)
                .lineLimit(1)

            if !space.appLayouts.isEmpty {
                Text("\(space.appLayouts.count) apps")
                    .font(.caption2)
                    .foregroundStyle(space.isActive ? .white.opacity(0.7) : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background {
            if space.isActive {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.gradient)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.fill.quaternary)
            }
        }
        .overlay(alignment: .center) {
            if space.isActive {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1)
            } else if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            }
        }
        .scaleEffect(space.isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: space.isActive)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct MiniMapWindow: View {
    var body: some View {
        MiniMapView()
            .frame(width: 300, height: 450)
    }
}
