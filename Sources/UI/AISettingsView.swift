import SwiftUI

@MainActor
struct AISettingsView: View {
    @Environment(SettingsStore.self) private var settings

    @State private var showRemoteAIWarning = false

    var body: some View {
        @Bindable var store = settings
        Form {
            Section(L10n.smartFeatures.localized) {
                Toggle(L10n.useAIEnhancement.localized, isOn: $store.useAIEnhancement)
                if store.useAIEnhancement {
                    Picker(L10n.aiType.localized, selection: $store.useAIType) {
                        ForEach(PrivacySettings.AIEnhancementType.allCases, id: \.self) { type in
                            Text(aiTypeLabel(type)).tag(type)
                        }
                    }
                    .onChange(of: store.useAIType) { _, newValue in
                        if newValue != .local {
                            showRemoteAIWarning = true
                        }
                    }
                }
            }

            if store.useAIEnhancement && store.useAIType != .local {
                Section(L10n.remoteAIConfig.localized) {
                    TextField(L10n.endpointURL.localized, text: $store.aiEndpointURL)
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
                    TextField(L10n.modelName.localized, text: $store.aiModelName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Stepper(L10n.maxTokens.localized(store.aiMaxTokens), value: $store.aiMaxTokens, in: 256...8192, step: 256)
                    HStack {
                        Text(L10n.temperature.localized(store.aiTemperature))
                        Slider(value: $store.aiTemperature, in: 0...1, step: 0.1)
                    }
                }
            }

            Section(L10n.dataRetention.localized) {
                Stepper {
                    Text(L10n.retainDataDays.localized(store.dataRetentionDays))
                } onIncrement: {
                    store.dataRetentionDays = min(store.dataRetentionDays + 7, 365)
                } onDecrement: {
                    store.dataRetentionDays = max(store.dataRetentionDays - 7, 1)
                }
                Text(L10n.olderDataDeleted.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert(L10n.remoteAIWarningTitle.localized, isPresented: $showRemoteAIWarning) {
            Button(L10n.understandAndAgree.localized, role: .cancel) { }
            Button(L10n.switchToLocalAI.localized) {
                settings.useAIType = .local
            }
        } message: {
            Text(L10n.remoteAIWarningMessage.localized)
        }
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
