import SwiftUI

@MainActor
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(L10n.general.localized, systemImage: "gearshape")
                }

            SpacesSettingsView()
                .tabItem {
                    Label(L10n.spaces.localized, systemImage: "square.split.2x2")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label(L10n.shortcuts.localized, systemImage: "keyboard")
                }

            PrivacySettingsView()
                .tabItem {
                    Label(L10n.privacy.localized, systemImage: "hand.raised")
                }

            LanguageCloudSettingsView()
                .tabItem {
                    Label(L10n.language.localized, systemImage: "globe")
                }

            AISettingsView()
                .tabItem {
                    Label(L10n.smartFeatures.localized, systemImage: "brain")
                }

            SettingsTimelineView()
                .tabItem {
                    Label(L10n.timeline.localized, systemImage: "clock.arrow.circlepath")
                }

            CoachingView()
                .tabItem {
                    Label(L10n.coach.localized, systemImage: "lightbulb.max.fill")
                }

            TransparencyDashboardView()
                .tabItem {
                    Label(L10n.monitor.localized, systemImage: "eye.fill")
                }
        }
        .scenePadding()
        .frame(minWidth: 550, minHeight: 420)
        .localeAware(LocalizationManager.shared.currentLanguage)
    }
}

@MainActor
struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(L10n.general.localized) {
                Toggle(L10n.launchAtLogin.localized, isOn: $settings.launchAtLogin)
                Toggle(L10n.autoSwitchSpaces.localized, isOn: $settings.isAutoSwitchEnabled)
            }

            Section(L10n.spaces.localized) {
                Toggle(L10n.showMenuBarIcon.localized, isOn: $settings.showMenuBarIcon)
                Toggle(L10n.showNotifications.localized, isOn: $settings.showNotifications)
            }

            Section(L10n.monitoring.localized) {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $settings.pollingInterval, in: 0.5...5.0, step: 0.5) {
                        Text(L10n.pollingInterval.localized)
                    } minimumValueLabel: {
                        Text("0.5s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("5s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(settings.pollingInterval, specifier: "%.1f") \(L10n.seconds.localized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.data.localized) {
                Stepper {
                    Text(L10n.snapshotRetentionDays.localized(settings.snapshotRetentionDays))
                } onIncrement: {
                    settings.snapshotRetentionDays = min(settings.snapshotRetentionDays + 1, Constants.maxSnapshotRetentionDays)
                } onDecrement: {
                    settings.snapshotRetentionDays = max(settings.snapshotRetentionDays - 1, 1)
                }
            }
        }
        .formStyle(.grouped)
    }
}

@MainActor
struct SpacesSettingsView: View {
    @Environment(SpaceStore.self) private var spaceStore

    var body: some View {
        if spaceStore.spaces.isEmpty {
            ContentUnavailableView(
                L10n.noSpaces.localized,
                systemImage: "square.split.2x2",
                description: Text(L10n.createSpacesDescription.localized)
            )
        } else {
            List {
                ForEach(spaceStore.spaces) { space in
                    HStack {
                        Image(systemName: space.iconName)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(space.name)
                            Text(space.mode.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if space.isActive {
                            Text(L10n.active.localized)
                                .foregroundStyle(.green)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if let space = spaceStore.spaces[safe: index] {
                            spaceStore.removeSpace(space)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

@MainActor
struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section(L10n.keyboardShortcuts.localized) {
                shortcutRow(.toggleWindow, shortcut: "\u{2318}\u{2325}T")
                shortcutRow(.nextSpace, shortcut: "\u{2318}\u{2325}\u{2192}")
                shortcutRow(.previousSpace, shortcut: "\u{2318}\u{2325}\u{2190}")
                shortcutRow(.captureSnapshot, shortcut: "\u{2318}\u{2325}S")
                shortcutRow(.quickSwitch, shortcut: "\u{2318}\u{2325}Space")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ key: L10n, shortcut: String) -> some View {
        HStack {
            Text(key.localized)
            Spacer()
            Text(shortcut)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.fill.quaternary)
                .clipShape(.rect(cornerRadius: 4))
        }
    }
}
