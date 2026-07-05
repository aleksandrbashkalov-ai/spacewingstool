import Foundation
import CloudKit

public actor CloudSyncService {
    public static let shared = CloudSyncService()

    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    private init() {
        self.container = CKContainer(identifier: "iCloud.\(Constants.appBundleID)")
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: "ActivitySync", ownerName: CKCurrentUserDefaultName)
    }

    public var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    public func sync() async {
        guard isAvailable else {
            Log.warning("iCloud not available for sync")
            return
        }
        let shouldSyncReading = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.syncReading) as? Bool ?? false
        let shouldSyncWriting = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.syncWriting) as? Bool ?? false
        let shouldSyncEmail = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.syncEmail) as? Bool ?? false
        let shouldSyncMedia = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.syncMedia) as? Bool ?? false
        let shouldSyncMeetings = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.syncMeetings) as? Bool ?? false

        var enabledTypes: [String] = []
        if shouldSyncReading { enabledTypes.append("reading") }
        if shouldSyncWriting { enabledTypes.append("writing") }
        if shouldSyncEmail { enabledTypes.append("email") }
        if shouldSyncMedia { enabledTypes.append("media") }
        if shouldSyncMeetings { enabledTypes.append("meeting") }

        guard !enabledTypes.isEmpty else {
            Log.info("No categories enabled for sync")
            return
        }

        Log.info("Starting iCloud sync for categories: \(enabledTypes.joined(separator: ", "))")

        do {
            try await syncRecords(categories: enabledTypes)
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
            Log.info("iCloud sync completed successfully")
        } catch {
            Log.error("iCloud sync failed: \(error.localizedDescription)")
        }
    }

    private func syncRecords(categories: [String]) async throws {
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date.distantPast
        let since = lastSync.addingTimeInterval(-300)

        guard let records = try? await ActivityTracker.shared.records(in: since...Date()) else { return }

        for record in records {
            let type = record.activityType.rawValue.lowercased()
            guard categories.contains(type) else { continue }
            try await uploadRecord(record)
        }
    }

    private func uploadRecord(_ record: ActivityRecord) async throws {
        let recordID = CKRecord.ID(recordName: record.id, zoneID: zoneID)
        let ckRecord = CKRecord(recordType: "ActivityRecord", recordID: recordID)
        ckRecord["activityType"] = record.activityType.rawValue as CKRecordValue
        ckRecord["appName"] = (record.appName ?? "") as CKRecordValue
        ckRecord["title"] = (record.title ?? "") as CKRecordValue
        ckRecord["category"] = (record.category ?? "") as CKRecordValue
        ckRecord["duration"] = record.duration as CKRecordValue
        ckRecord["timestamp"] = record.timestamp as CKRecordValue

        do {
            _ = try await database.save(ckRecord)
        } catch {
            Log.warning("Failed to upload record \(record.id): \(error.localizedDescription)")
        }
    }
}
