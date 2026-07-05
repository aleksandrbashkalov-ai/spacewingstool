import SwiftUI

@MainActor
struct LanguageCloudSettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        let langMgr = LocalizationManager.shared

        Form {
            Section(L10n.language.localized) {
                Picker(L10n.language.localized, selection: Bindable(langMgr).currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        HStack {
                            Text(lang.flag)
                            Text(lang.rawValue)
                        }
                        .tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(L10n.icloudSync.localized) {
                Toggle(L10n.syncReading.localized, isOn: $settings.syncReading)
                Toggle(L10n.syncWriting.localized, isOn: $settings.syncWriting)
                Toggle(L10n.syncEmail.localized, isOn: $settings.syncEmail)
                Toggle(L10n.syncMedia.localized, isOn: $settings.syncMedia)
                Toggle(L10n.syncMeetings.localized, isOn: $settings.syncMeetings)

                Toggle(L10n.syncAll.localized, isOn: Binding(
                    get: { settings.syncReading && settings.syncWriting && settings.syncEmail && settings.syncMedia && settings.syncMeetings },
                    set: { newValue in
                        settings.syncReading = newValue
                        settings.syncWriting = newValue
                        settings.syncEmail = newValue
                        settings.syncMedia = newValue
                        settings.syncMeetings = newValue
                    }
                ))

                Divider()

                HStack {
                    Text(L10n.lastSync.localized(lastSyncLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.syncNow.localized) {
                        Task { await triggerSync() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }

    @MainActor
    private var lastSyncLabel: String {
        let last = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        guard let last else { return L10n.never.localized }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: last)
    }

    private func triggerSync() async {
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        await CloudSyncService.shared.sync()
    }
}
