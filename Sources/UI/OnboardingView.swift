import SwiftUI

@MainActor
struct OnboardingView: View {
    @State private var currentStep = 0
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(SpaceStore.self) private var spaceStore
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, title: L10n, description: L10n, color: Color)] = [
        ("square.split.2x2", .welcomeTitle, .welcomeDesc, .blue),
        ("brain.head.profile", .contextDetectionTitle, .contextDetectionDesc, .purple),
        ("arrow.triangle.2.circlepath", .autoSwitchTitle, .autoSwitchDesc, .green),
        ("clock.arrow.circlepath", .sessionMemoryTitle, .sessionMemoryDesc, .orange),
        ("crown", .readyTitle, .readyDesc, .accentColor),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepView(step, index: index)
                        .tag(index)
                }
            }
            .frame(height: 300)
            .animation(.easeInOut, value: currentStep)

            HStack {
                if currentStep > 0 {
                    Button(L10n.back.localized) {
                        withAnimation(.easeInOut) { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Previous step")
                }

                Spacer()

                Button(currentStep == steps.count - 1 ? L10n.getStarted.localized : L10n.continue.localized) {
                    if currentStep == steps.count - 1 {
                        settingsStore.isAutoSwitchEnabled = true
                        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.onboardingComplete)
                        dismiss()
                    } else {
                        withAnimation(.easeInOut) { currentStep += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityHint(currentStep == steps.count - 1 ? "Finish setup" : "Go to next step")
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500, height: 420)
        .localeAware(LocalizationManager.shared.currentLanguage)
    }

    private func stepView(_ step: (icon: String, title: L10n, description: L10n, color: Color), index: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: step.icon)
                .font(.system(size: 48))
                .foregroundStyle(step.color)
                .symbolEffect(.bounce, options: .nonRepeating, value: currentStep)

            Text(step.title.localized)
                .font(.title2)
                .fontWeight(.bold)

            Text(step.description.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if index == 1 {
                Toggle(L10n.enableAutoSwitch.localized, isOn: Bindable(settingsStore).isAutoSwitchEnabled)
                    .toggleStyle(.switch)
                    .padding(.horizontal, 40)
            }

            if index == 3 {
                Button(L10n.createFirstSpace.localized) {
                    spaceStore.addSpace(name: "My Workspace")
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title.localized): \(step.description.localized)")
    }
}
