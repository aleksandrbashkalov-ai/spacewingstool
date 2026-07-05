import Foundation

public actor SettingsTimelineManager {
    public static let shared = SettingsTimelineManager()

    private var database: ActivityDatabase?
    private var lastSnapshotTask: Task<Void, Never>?
    private var lastAutoSnapshot: Date = .distantPast

    private init() {}

    public func setDatabase(_ db: ActivityDatabase) {
        self.database = db
    }

    // MARK: - Capture

    public func captureSnapshot(label: String? = nil, source: SnapshotSource = .manual) async {
        guard let db = database else { return }

        let settings = collectCurrentSettings()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .sortedKeys),
              let json = String(data: jsonData, encoding: .utf8) else { return }

        let snapshot = SettingsSnapshot(
            label: label,
            settingsJSON: json,
            source: source
        )

        do {
            try db.insertSnapshot(snapshot)
            try db.pruneSnapshots(keepLast: 100)
            Log.info("Settings snapshot captured: \(label ?? "untitled")")
        } catch {
            Log.error("Failed to capture settings snapshot: \(error.localizedDescription)")
        }
    }

    public func autoSnapshotIfNeeded() async {
        let minInterval: TimeInterval = 300
        guard Date().timeIntervalSince(lastAutoSnapshot) > minInterval else { return }
        lastAutoSnapshot = Date()
        await captureSnapshot(label: "auto", source: .automatic)
    }

    public func scheduleAutoSnapshot() {
        lastSnapshotTask?.cancel()
        lastSnapshotTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                await self?.autoSnapshotIfNeeded()
            }
        }
    }

    // MARK: - Query

    public func snapshots(limit: Int = 50) async -> [SettingsSnapshot] {
        guard let db = database else { return [] }
        return (try? db.snapshots(limit: limit)) ?? []
    }

    public func snapshot(id: String) async -> SettingsSnapshot? {
        guard let db = database else { return nil }
        return try? db.snapshot(id: id)
    }

    // MARK: - Diff

    public func diff(between first: SettingsSnapshot, and second: SettingsSnapshot) -> SettingsDiff {
        let firstSettings = first.decodedSettings ?? [:]
        let secondSettings = second.decodedSettings ?? [:]

        var added: [String: String] = [:]
        var removed: [String: String] = [:]
        var changed: [ChangedSetting] = []

        let allKeys = Set(firstSettings.keys).union(secondSettings.keys)

        for key in allKeys {
            let oldVal = firstSettings[key]
            let newVal = secondSettings[key]

            switch (oldVal, newVal) {
            case (nil, let new?):
                added[key] = "\(new)"
            case (let old?, nil):
                removed[key] = "\(old)"
            case (let old?, let new?):
                let oldStr = "\(old)".trimmingCharacters(in: .whitespacesAndNewlines)
                let newStr = "\(new)".trimmingCharacters(in: .whitespacesAndNewlines)
                if oldStr != newStr {
                    changed.append(ChangedSetting(key: key, oldValue: oldStr, newValue: newStr))
                }
            case (nil, nil):
                break
            }
        }

        return SettingsDiff(added: added, removed: removed, changed: changed)
    }

    public func diffSince(_ snapshot: SettingsSnapshot) async -> SettingsDiff? {
        let currentJSON = collectCurrentSettings()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: currentJSON, options: .sortedKeys),
              let json = String(data: jsonData, encoding: .utf8) else { return nil }

        let current = SettingsSnapshot(settingsJSON: json, source: .manual)
        return diff(between: snapshot, and: current)
    }

    // MARK: - Rollback

    public func rollback(to snapshot: SettingsSnapshot) async -> Bool {
        guard let settings = snapshot.decodedSettings else { return false }
        let defaults = UserDefaults.standard

        for (key, value) in settings {
            switch value {
            case let bool as Bool:
                defaults.set(bool, forKey: key)
            case let int as Int:
                defaults.set(int, forKey: key)
            case let double as Double:
                defaults.set(double, forKey: key)
            case let string as String:
                defaults.set(string, forKey: key)
            default:
                if let data = try? JSONSerialization.data(withJSONObject: value),
                   let json = String(data: data, encoding: .utf8) {
                    defaults.set(json, forKey: key)
                }
            }
        }

        await captureSnapshot(
            label: snapshot.label.map { "rollback: \($0)" } ?? "rollback",
            source: .rollback
        )

        Log.info("Settings rolled back to snapshot: \(snapshot.label ?? snapshot.id)")
        return true
    }

    // MARK: - AI Suggestions

    public func suggestChanges() async -> String? {
        guard useAIEnhancement() else { return nil }

        let provider: AIProvider? = resolveAIProvider()
        guard let provider else { return nil }

        let snapshots = await self.snapshots(limit: 5)
        let current = collectCurrentSettings()

        let systemPrompt = """
        You are a productivity settings advisor. Based on the user's current settings \
        and recent changes, suggest 2-3 concrete improvements to optimize their workspace \
        management experience. Be specific about which setting to change and why.
        """

        var userMsg = "Current Settings:\n"
        for (key, val) in current.sorted(by: { $0.key < $1.key }) {
            userMsg += "  \(key): \(val)\n"
        }

        if !snapshots.isEmpty {
            userMsg += "\nRecent changes (last \(min(snapshots.count, 5)) snapshots):\n"
            for snap in snapshots.prefix(5) {
                userMsg += "  \(snap.timestamp): \(snap.label ?? "auto")\n"
            }
        }

        do {
            return try await provider.generateSummary(systemPrompt: systemPrompt, userMessage: userMsg)
        } catch {
            Log.error("AI suggestion failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private

    private func collectCurrentSettings() -> [String: Any] {
        let defaults = UserDefaults.standard
        let keys = Constants.UserDefaultsKeys.self
        let relevantKeys: [String] = [
            keys.autoSwitch, keys.pollingInterval, keys.showMiniMap, keys.showMenuBarIcon,
            keys.showNotifications, keys.snapshotRetentionDays, keys.trackReading,
            keys.trackReadingContent, keys.trackWriting, keys.trackWritingContent,
            keys.trackEmail, keys.trackEmailBody, keys.trackMedia, keys.trackMeetings,
            keys.recordMeetingAudio, keys.dataRetentionDays, keys.useAIEnhancement,
            keys.useAIType, keys.aiEndpointURL, keys.aiModelName, keys.aiMaxTokens,
            keys.aiTemperature, keys.syncReading, keys.syncWriting, keys.syncEmail,
            keys.syncMedia, keys.syncMeetings,
        ]
        var settings: [String: Any] = [:]
        for key in relevantKeys {
            if let val = defaults.object(forKey: key) {
                settings[key] = val
            }
        }
        return settings
    }

    private func useAIEnhancement() -> Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.useAIEnhancement) as? Bool ?? false
    }

    private func resolveAIProvider() -> AIProvider? {
        let aiType = PrivacySettings.AIEnhancementType(
            rawValue: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.useAIType) ?? "Local AI Only"
        ) ?? .local

        switch aiType {
        case .local: return LocalAIProvider.shared
        case .remote, .both: return RemoteAIProvider.shared
        }
    }
}
