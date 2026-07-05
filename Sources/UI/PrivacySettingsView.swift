import SwiftUI

@MainActor
struct PrivacySettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                permissionRow(type: .accessibility)
                permissionRow(type: .screenRecording)
                permissionRow(type: .microphone)
            } header: {
                Text(L10n.permissions.localized)
            } footer: {
                Text(L10n.permFooter.localized)
            }

            Section(L10n.readingTracking.localized) {
                Toggle(L10n.trackReading.localized, isOn: $settings.trackReading)
                if settings.trackReading {
                    Picker(L10n.contentCapture.localized, selection: $settings.trackReadingContent) {
                        ForEach(PrivacySettings.ContentCaptureLevel.allCases, id: \.self) { level in
                            Text(captureLevelLabel(level)).tag(level)
                        }
                    }
                }
            }

            Section(L10n.writingTracking.localized) {
                Toggle(L10n.trackWriting.localized, isOn: $settings.trackWriting)
                if settings.trackWriting {
                    Picker(L10n.contentCapture.localized, selection: $settings.trackWritingContent) {
                        ForEach(PrivacySettings.WritingContentCapture.allCases, id: \.self) { level in
                            Text(writingCaptureLabel(level)).tag(level)
                        }
                    }
                }
            }

            Section(L10n.emailTracking.localized) {
                Toggle(L10n.trackEmail.localized, isOn: $settings.trackEmail)
                if settings.trackEmail {
                    Picker(L10n.bodyCapture.localized, selection: $settings.trackEmailBody) {
                        ForEach(PrivacySettings.ContentCaptureLevel.allCases, id: \.self) { level in
                            Text(captureLevelLabel(level)).tag(level)
                        }
                    }
                }
            }

            Section(L10n.mediaTracking.localized) {
                Toggle(L10n.trackMedia.localized, isOn: $settings.trackMedia)
            }

            Section(L10n.meetingTracking.localized) {
                Toggle(L10n.trackMeetings.localized, isOn: $settings.trackMeetings)
                if settings.trackMeetings {
                    Toggle(L10n.recordMeetingAudio.localized, isOn: $settings.recordMeetingAudio)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func captureLevelLabel(_ level: PrivacySettings.ContentCaptureLevel) -> String {
        switch level {
        case .off: return L10n.off.localized
        case .preview: return L10n.preview.localized
        case .full: return L10n.full.localized
        }
    }

    private func writingCaptureLabel(_ level: PrivacySettings.WritingContentCapture) -> String {
        switch level {
        case .off: return L10n.off.localized
        case .metadataOnly: return L10n.metadataOnly.localized
        case .selectedText: return L10n.selectedText.localized
        }
    }

    private func permissionRow(type: PermissionType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(permissionLabel(type))
                    .font(.body)
                Text(permissionDescription(type))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PermissionBadge(type: type)
        }
    }

    private func permissionLabel(_ type: PermissionType) -> String {
        switch type {
        case .accessibility: return L10n.accessibility.localized
        case .screenRecording: return L10n.screenRecording.localized
        case .microphone: return L10n.microphone.localized
        case .notifications: return L10n.showNotifications.localized
        case .fullDiskAccess: return L10n.fullDiskAccess.localized
        }
    }

    private func permissionDescription(_ type: PermissionType) -> String {
        switch type {
        case .accessibility: return L10n.permAccessibilityDesc.localized
        case .screenRecording: return L10n.permScreenRecordingDesc.localized
        case .microphone: return L10n.permMicrophoneDesc.localized
        case .notifications: return L10n.permNotificationsDesc.localized
        case .fullDiskAccess: return L10n.permFullDiskDesc.localized
        }
    }
}

@MainActor
private struct PermissionBadge: View {
    let type: PermissionType

    @State private var state: PermissionState = .notRequested

    var body: some View {
        Group {
            switch state {
            case .granted:
                Label(L10n.granted.localized, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied, .restricted:
                Button(L10n.fixInSettings.localized) {
                    openSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            case .notRequested:
                Button(L10n.request.localized) {
                    Task { await request() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .font(.caption)
        .task {
            state = await PermissionsManager.shared.currentState(type)
        }
    }

    private func request() async {
        state = await PermissionsManager.shared.request(type)
    }

    private func openSettings() {
        switch type {
        case .accessibility: PermissionsManager.openAccessibilitySettings()
        case .screenRecording: PermissionsManager.openScreenRecordingSettings()
        case .microphone: PermissionsManager.openPrivacySettings()
        case .notifications: break
        case .fullDiskAccess: PermissionsManager.openPrivacySettings()
        }
    }
}
