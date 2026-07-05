import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    public var isAutoSwitchEnabled: Bool {
        didSet { UserDefaults.standard.set(isAutoSwitchEnabled, forKey: Constants.UserDefaultsKeys.autoSwitch) }
    }
    public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserDefaultsKeys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    public var pollingInterval: Double {
        didSet { UserDefaults.standard.set(pollingInterval, forKey: Constants.UserDefaultsKeys.pollingInterval) }
    }
    public var showMiniMap: Bool {
        didSet { UserDefaults.standard.set(showMiniMap, forKey: Constants.UserDefaultsKeys.showMiniMap) }
    }
    public var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: Constants.UserDefaultsKeys.showMenuBarIcon) }
    }
    public var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: Constants.UserDefaultsKeys.showNotifications) }
    }
    public var snapshotRetentionDays: Int {
        didSet { UserDefaults.standard.set(snapshotRetentionDays, forKey: Constants.UserDefaultsKeys.snapshotRetentionDays) }
    }

    // Privacy Settings
    public var trackReading: Bool {
        didSet { UserDefaults.standard.set(trackReading, forKey: Constants.UserDefaultsKeys.trackReading) }
    }
    public var trackReadingContent: PrivacySettings.ContentCaptureLevel {
        didSet { UserDefaults.standard.set(trackReadingContent.rawValue, forKey: Constants.UserDefaultsKeys.trackReadingContent) }
    }
    public var trackWriting: Bool {
        didSet { UserDefaults.standard.set(trackWriting, forKey: Constants.UserDefaultsKeys.trackWriting) }
    }
    public var trackWritingContent: PrivacySettings.WritingContentCapture {
        didSet { UserDefaults.standard.set(trackWritingContent.rawValue, forKey: Constants.UserDefaultsKeys.trackWritingContent) }
    }
    public var trackEmail: Bool {
        didSet { UserDefaults.standard.set(trackEmail, forKey: Constants.UserDefaultsKeys.trackEmail) }
    }
    public var trackEmailBody: PrivacySettings.ContentCaptureLevel {
        didSet { UserDefaults.standard.set(trackEmailBody.rawValue, forKey: Constants.UserDefaultsKeys.trackEmailBody) }
    }
    public var trackMedia: Bool {
        didSet { UserDefaults.standard.set(trackMedia, forKey: Constants.UserDefaultsKeys.trackMedia) }
    }
    public var trackMeetings: Bool {
        didSet { UserDefaults.standard.set(trackMeetings, forKey: Constants.UserDefaultsKeys.trackMeetings) }
    }
    public var recordMeetingAudio: Bool {
        didSet { UserDefaults.standard.set(recordMeetingAudio, forKey: Constants.UserDefaultsKeys.recordMeetingAudio) }
    }
    public var dataRetentionDays: Int {
        didSet { UserDefaults.standard.set(dataRetentionDays, forKey: Constants.UserDefaultsKeys.dataRetentionDays) }
    }
    public var useAIEnhancement: Bool {
        didSet { UserDefaults.standard.set(useAIEnhancement, forKey: Constants.UserDefaultsKeys.useAIEnhancement) }
    }
    public var useAIType: PrivacySettings.AIEnhancementType {
        didSet { UserDefaults.standard.set(useAIType.rawValue, forKey: Constants.UserDefaultsKeys.useAIType) }
    }
    public var aiEndpointURL: String {
        didSet { UserDefaults.standard.set(aiEndpointURL, forKey: Constants.UserDefaultsKeys.aiEndpointURL) }
    }
    public var aiModelName: String {
        didSet { UserDefaults.standard.set(aiModelName, forKey: Constants.UserDefaultsKeys.aiModelName) }
    }
    public var aiMaxTokens: Int {
        didSet { UserDefaults.standard.set(aiMaxTokens, forKey: Constants.UserDefaultsKeys.aiMaxTokens) }
    }
    public var aiTemperature: Double {
        didSet { UserDefaults.standard.set(aiTemperature, forKey: Constants.UserDefaultsKeys.aiTemperature) }
    }

    // iCloud Sync
    public var syncReading: Bool {
        didSet { UserDefaults.standard.set(syncReading, forKey: Constants.UserDefaultsKeys.syncReading) }
    }
    public var syncWriting: Bool {
        didSet { UserDefaults.standard.set(syncWriting, forKey: Constants.UserDefaultsKeys.syncWriting) }
    }
    public var syncEmail: Bool {
        didSet { UserDefaults.standard.set(syncEmail, forKey: Constants.UserDefaultsKeys.syncEmail) }
    }
    public var syncMedia: Bool {
        didSet { UserDefaults.standard.set(syncMedia, forKey: Constants.UserDefaultsKeys.syncMedia) }
    }
    public var syncMeetings: Bool {
        didSet { UserDefaults.standard.set(syncMeetings, forKey: Constants.UserDefaultsKeys.syncMeetings) }
    }

    private init() {
        let defaults = UserDefaults.standard
        let defaultPrivacy = PrivacySettings.default
        self.isAutoSwitchEnabled = defaults.object(forKey: Constants.UserDefaultsKeys.autoSwitch) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: Constants.UserDefaultsKeys.launchAtLogin) as? Bool ?? false
        self.pollingInterval = defaults.object(forKey: Constants.UserDefaultsKeys.pollingInterval) as? Double ?? Constants.defaultPollingInterval
        self.showMiniMap = defaults.object(forKey: Constants.UserDefaultsKeys.showMiniMap) as? Bool ?? true
        self.showMenuBarIcon = defaults.object(forKey: Constants.UserDefaultsKeys.showMenuBarIcon) as? Bool ?? true
        self.showNotifications = defaults.object(forKey: Constants.UserDefaultsKeys.showNotifications) as? Bool ?? true
        self.snapshotRetentionDays = defaults.object(forKey: Constants.UserDefaultsKeys.snapshotRetentionDays) as? Int ?? Constants.defaultSnapshotRetentionDays
        self.trackReading = defaults.object(forKey: Constants.UserDefaultsKeys.trackReading) as? Bool ?? defaultPrivacy.trackReading
        self.trackReadingContent = defaults.string(forKey: Constants.UserDefaultsKeys.trackReadingContent).flatMap(PrivacySettings.ContentCaptureLevel.init(rawValue:)) ?? defaultPrivacy.trackReadingContent
        self.trackWriting = defaults.object(forKey: Constants.UserDefaultsKeys.trackWriting) as? Bool ?? defaultPrivacy.trackWriting
        self.trackWritingContent = defaults.string(forKey: Constants.UserDefaultsKeys.trackWritingContent).flatMap(PrivacySettings.WritingContentCapture.init(rawValue:)) ?? defaultPrivacy.trackWritingContent
        self.trackEmail = defaults.object(forKey: Constants.UserDefaultsKeys.trackEmail) as? Bool ?? defaultPrivacy.trackEmail
        self.trackEmailBody = defaults.string(forKey: Constants.UserDefaultsKeys.trackEmailBody).flatMap(PrivacySettings.ContentCaptureLevel.init(rawValue:)) ?? defaultPrivacy.trackEmailBody
        self.trackMedia = defaults.object(forKey: Constants.UserDefaultsKeys.trackMedia) as? Bool ?? defaultPrivacy.trackMedia
        self.trackMeetings = defaults.object(forKey: Constants.UserDefaultsKeys.trackMeetings) as? Bool ?? defaultPrivacy.trackMeetings
        self.recordMeetingAudio = defaults.object(forKey: Constants.UserDefaultsKeys.recordMeetingAudio) as? Bool ?? defaultPrivacy.recordMeetingAudio
        self.dataRetentionDays = defaults.object(forKey: Constants.UserDefaultsKeys.dataRetentionDays) as? Int ?? defaultPrivacy.dataRetentionDays
        self.useAIEnhancement = defaults.object(forKey: Constants.UserDefaultsKeys.useAIEnhancement) as? Bool ?? defaultPrivacy.useAIEnhancement
        self.useAIType = defaults.string(forKey: Constants.UserDefaultsKeys.useAIType).flatMap(PrivacySettings.AIEnhancementType.init(rawValue:)) ?? defaultPrivacy.useAIType
        self.aiEndpointURL = defaults.string(forKey: Constants.UserDefaultsKeys.aiEndpointURL) ?? "https://api.openai.com/v1/chat/completions"
        self.aiModelName = defaults.string(forKey: Constants.UserDefaultsKeys.aiModelName) ?? "gpt-4o-mini"
        self.aiMaxTokens = defaults.object(forKey: Constants.UserDefaultsKeys.aiMaxTokens) as? Int ?? 1024
        self.aiTemperature = defaults.object(forKey: Constants.UserDefaultsKeys.aiTemperature) as? Double ?? 0.7
        self.syncReading = defaults.object(forKey: Constants.UserDefaultsKeys.syncReading) as? Bool ?? false
        self.syncWriting = defaults.object(forKey: Constants.UserDefaultsKeys.syncWriting) as? Bool ?? false
        self.syncEmail = defaults.object(forKey: Constants.UserDefaultsKeys.syncEmail) as? Bool ?? false
        self.syncMedia = defaults.object(forKey: Constants.UserDefaultsKeys.syncMedia) as? Bool ?? false
        self.syncMeetings = defaults.object(forKey: Constants.UserDefaultsKeys.syncMeetings) as? Bool ?? false
    }

    public func resetToDefaults() {
        let defaults = UserDefaults.standard
        let knownKeys: [String] = [
            Constants.UserDefaultsKeys.autoSwitch, Constants.UserDefaultsKeys.launchAtLogin,
            Constants.UserDefaultsKeys.pollingInterval, Constants.UserDefaultsKeys.showMiniMap,
            Constants.UserDefaultsKeys.showMenuBarIcon, Constants.UserDefaultsKeys.showNotifications,
            Constants.UserDefaultsKeys.snapshotRetentionDays,
            Constants.UserDefaultsKeys.trackReading, Constants.UserDefaultsKeys.trackReadingContent,
            Constants.UserDefaultsKeys.trackWriting, Constants.UserDefaultsKeys.trackWritingContent,
            Constants.UserDefaultsKeys.trackEmail, Constants.UserDefaultsKeys.trackEmailBody,
            Constants.UserDefaultsKeys.trackMedia, Constants.UserDefaultsKeys.trackMeetings,
            Constants.UserDefaultsKeys.recordMeetingAudio, Constants.UserDefaultsKeys.dataRetentionDays,
            Constants.UserDefaultsKeys.useAIEnhancement, Constants.UserDefaultsKeys.useAIType,
            Constants.UserDefaultsKeys.aiEndpointURL, Constants.UserDefaultsKeys.aiModelName,
            Constants.UserDefaultsKeys.aiMaxTokens, Constants.UserDefaultsKeys.aiTemperature,
            Constants.UserDefaultsKeys.syncReading, Constants.UserDefaultsKeys.syncWriting,
            Constants.UserDefaultsKeys.syncEmail, Constants.UserDefaultsKeys.syncMedia,
            Constants.UserDefaultsKeys.syncMeetings,
        ]
        for key in knownKeys {
            defaults.removeObject(forKey: key)
        }
        let dp = PrivacySettings.default
        isAutoSwitchEnabled = true
        launchAtLogin = false
        pollingInterval = Constants.defaultPollingInterval
        showMiniMap = true
        showMenuBarIcon = true
        showNotifications = true
        snapshotRetentionDays = Constants.defaultSnapshotRetentionDays
        trackReading = dp.trackReading
        trackReadingContent = dp.trackReadingContent
        trackWriting = dp.trackWriting
        trackWritingContent = dp.trackWritingContent
        trackEmail = dp.trackEmail
        trackEmailBody = dp.trackEmailBody
        trackMedia = dp.trackMedia
        trackMeetings = dp.trackMeetings
        recordMeetingAudio = dp.recordMeetingAudio
        dataRetentionDays = dp.dataRetentionDays
        useAIEnhancement = dp.useAIEnhancement
        useAIType = dp.useAIType
        aiEndpointURL = "https://api.openai.com/v1/chat/completions"
        aiModelName = "gpt-4o-mini"
        aiMaxTokens = 1024
        aiTemperature = 0.7
        syncReading = false
        syncWriting = false
        syncEmail = false
        syncMedia = false
        syncMeetings = false
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.error("Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}
