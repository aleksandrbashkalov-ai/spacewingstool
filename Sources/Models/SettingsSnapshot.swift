import Foundation

public struct SettingsSnapshot: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var timestamp: Date
    public var label: String?
    public var settingsJSON: String
    public var source: SnapshotSource
    public var aiSuggestionID: String?

    public var decodedSettings: [String: Any]? {
        guard let data = settingsJSON.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    public init(id: String = UUID().uuidString, timestamp: Date = Date(), label: String? = nil,
                settingsJSON: String, source: SnapshotSource = .manual,
                aiSuggestionID: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.settingsJSON = settingsJSON
        self.source = source
        self.aiSuggestionID = aiSuggestionID
    }
}

public enum SnapshotSource: String, Codable, Sendable, CaseIterable {
    case manual
    case automatic
    case aiSuggestion
    case rollback
}

public struct ChangedSetting: Codable, Sendable, Equatable {
    public var key: String
    public var oldValue: String
    public var newValue: String

    public init(key: String, oldValue: String, newValue: String) {
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

public struct SettingsDiff: Codable, Sendable, Equatable {
    public var added: [String: String]
    public var removed: [String: String]
    public var changed: [ChangedSetting]

    public var isEmpty: Bool { added.isEmpty && removed.isEmpty && changed.isEmpty }
    public var changeCount: Int { added.count + removed.count + changed.count }

    public init(added: [String: String] = [:], removed: [String: String] = [:],
                changed: [ChangedSetting] = []) {
        self.added = added
        self.removed = removed
        self.changed = changed
    }
}
