import SwiftUI

@MainActor
struct AISettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(L10n.aiEnhancement.localized) {
                Toggle(L10n.useAIEnhancement.localized, isOn: $settings.useAIEnhancement)
                if settings.useAIEnhancement {
                    Picker(L10n.aiType.localized, selection: $settings.useAIType) {
                        ForEach(PrivacySettings.AIEnhancementType.allCases, id: \.self) { type in
                            Text(aiTypeLabel(type)).tag(type)
                        }
                    }
                }
            }

            if settings.useAIEnhancement && settings.useAIType != .local {
                Section(L10n.remoteAIConfig.localized) {
                    TextField(L10n.endpointURL.localized, text: $settings.aiEndpointURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    HStack {
                        SecureField(L10n.apiKey.localized, text: apiKeyBinding)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button(L10n.save.localized) {
                            let newKey = apiKeyBinding.wrappedValue
                            if !newKey.isEmpty {
                                _ = KeychainService.save(key: Constants.UserDefaultsKeys.aiAPIKey, value: newKey)
                                Task { await RemoteAIProvider.shared.reloadConfiguration() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    TextField(L10n.modelName.localized, text: $settings.aiModelName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Stepper(L10n.maxTokens.localized(settings.aiMaxTokens), value: $settings.aiMaxTokens, in: 256...8192, step: 256)
                    HStack {
                        Text(L10n.temperature.localized(settings.aiTemperature))
                        Slider(value: $settings.aiTemperature, in: 0...1, step: 0.1)
                    }
                }
            }

            Section(L10n.dataRetention.localized) {
                Stepper {
                    Text(L10n.retainDataDays.localized(settings.dataRetentionDays))
                } onIncrement: {
                    settings.dataRetentionDays = min(settings.dataRetentionDays + 7, 365)
                } onDecrement: {
                    settings.dataRetentionDays = max(settings.dataRetentionDays - 7, 1)
                }
                Text(L10n.olderDataDeleted.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { KeychainService.load(key: Constants.UserDefaultsKeys.aiAPIKey) ?? "" },
            set: { _ in }
        )
    }

    private func aiTypeLabel(_ type: PrivacySettings.AIEnhancementType) -> String {
        switch type {
        case .local: return L10n.localAIOnly.localized
        case .remote: return L10n.remoteAI.localized
        case .both: return L10n.localPlusRemote.localized
        }
    }
}
