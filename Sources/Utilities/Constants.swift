import Foundation

public enum Constants {
    public static let appName = "Spacewingstool"
    public static let appVersion = "1.2.0"
    public static let appBundleID = "com.spacewingstool.app"

    public static let defaultPollingInterval: TimeInterval = 2.0
    public static let maxSnapshotCount = 50
    public static let defaultSnapshotRetentionDays = 30
    public static let maxSnapshotRetentionDays = 90

    public enum UserDefaultsKeys {
        public static let autoSwitch = "autoSwitch"
        public static let launchAtLogin = "launchAtLogin"
        public static let pollingInterval = "pollingInterval"
        public static let showMiniMap = "showMiniMap"
        public static let showMenuBarIcon = "showMenuBarIcon"
        public static let showNotifications = "showNotifications"
        public static let snapshotRetentionDays = "snapshotRetentionDays"
        public static let onboardingComplete = "onboardingComplete"

        // Privacy
        public static let trackReading = "privacy_trackReading"
        public static let trackReadingContent = "privacy_trackReadingContent"
        public static let trackWriting = "privacy_trackWriting"
        public static let trackWritingContent = "privacy_trackWritingContent"
        public static let trackEmail = "privacy_trackEmail"
        public static let trackEmailBody = "privacy_trackEmailBody"
        public static let trackMedia = "privacy_trackMedia"
        public static let trackMeetings = "privacy_trackMeetings"
        public static let recordMeetingAudio = "privacy_recordMeetingAudio"
        public static let dataRetentionDays = "privacy_dataRetentionDays"
        public static let useAIEnhancement = "privacy_useAIEnhancement"
        public static let useAIType = "privacy_useAIType"

        // AI Provider
        public static let aiEndpointURL = "ai_endpointURL"
        public static let aiAPIKey = "ai_apiKey"
        public static let aiModelName = "ai_modelName"
        public static let aiMaxTokens = "ai_maxTokens"
        public static let aiTemperature = "ai_temperature"

        // i18n + iCloud
        public static let language = "app_language"
        public static let syncReading = "sync_reading"
        public static let syncWriting = "sync_writing"
        public static let syncEmail = "sync_email"
        public static let syncMedia = "sync_media"
        public static let syncMeetings = "sync_meetings"
    }
}
