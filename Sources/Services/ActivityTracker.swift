import Foundation
import Observation

public enum ActivityTrackerEvent: Sendable {
    case recordInserted(ActivityRecord)
    case batchInserted(count: Int)
    case retentionCleaned(deleted: Int, before: Date)
    case error(Error)
}

public actor ActivityTracker {
    public static let shared = ActivityTracker()

    private var database: ActivityDatabase?
    private var isRunning = false
    private var maintenanceTask: Task<Void, Never>?
    private let stream = AsyncStream<ActivityTrackerEvent>.makeStream()

    public var events: AsyncStream<ActivityTrackerEvent> {
        stream.stream
    }

    private init() {}

    // MARK: - Lifecycle

    public func start(database: ActivityDatabase) {
        self.database = database
        self.isRunning = true
        startMaintenance()
        Log.info("ActivityTracker started")
    }

    public func stop() {
        isRunning = false
        maintenanceTask?.cancel()
        maintenanceTask = nil
        Log.info("ActivityTracker stopped")
    }

    public var isActive: Bool { isRunning }

    // MARK: - Record Management

    public func insert(_ record: ActivityRecord) async {
        guard isRunning, let db = database else { return }
        do {
            var enriched = record
            if enriched.signalWeight == nil {
                let weighted = await SignalPrioritizationService.shared.weightEvent(record)
                enriched.signalWeight = weighted.weight.rawValue
            }
            try db.insert(enriched)
            stream.continuation.yield(.recordInserted(enriched))
        } catch {
            Log.error("Failed to insert record: \(error.localizedDescription)")
            stream.continuation.yield(.error(error))
        }
    }

    public func insertBatch(_ records: [ActivityRecord]) async {
        guard isRunning, let db = database else { return }
        do {
            var enriched: [ActivityRecord] = []
            for record in records {
                guard record.signalWeight == nil else { enriched.append(record); continue }
                let weighted = await SignalPrioritizationService.shared.weightEvent(record)
                var copy = record
                copy.signalWeight = weighted.weight.rawValue
                enriched.append(copy)
            }
            try db.insertBatch(enriched)
            stream.continuation.yield(.batchInserted(count: enriched.count))
        } catch {
            Log.error("Failed to insert batch: \(error.localizedDescription)")
            stream.continuation.yield(.error(error))
        }
    }

    public func records(in range: ClosedRange<Date>, limit: Int = 200) throws -> [ActivityRecord] {
        guard let db = database else { return [] }
        return try db.records(in: range, limit: limit)
    }

    public func recentRecords(hours: Int = 24) throws -> [ActivityRecord] {
        guard let db = database else { return [] }
        return try db.recentRecords(hours: hours)
    }

    public func search(term: String) throws -> [ActivityRecord] {
        guard let db = database else { return [] }
        return try db.search(term: term)
    }

    public func activityTypeSummary(in range: ClosedRange<Date>) throws -> [(ActivityType, TimeInterval)] {
        guard let db = database else { return [] }
        return try db.activityTypeSummary(in: range)
    }

    // MARK: - Maintenance

    public func runRetentionCleanup() {
        guard let db = database else { return }
        let retentionDays = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.dataRetentionDays) as? Int ?? 30
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        do {
            let deleted = try db.deleteOlderThan(cutoff)
            if deleted > 0 {
                Log.info("Cleaned \(deleted) old records (before \(cutoff))")
                stream.continuation.yield(.retentionCleaned(deleted: deleted, before: cutoff))
            }
        } catch {
            Log.error("Retention cleanup failed: \(error.localizedDescription)")
        }
    }

    private func startMaintenance() {
        maintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runRetentionCleanup()
                try? await Task.sleep(nanoseconds: 86_400_000_000_000)
            }
        }
    }

    // MARK: - Database Info

    public func recordCount() throws -> Int {
        try database?.recordCount() ?? 0
    }

    public func databaseSize() throws -> UInt64 {
        try database?.databaseSize() ?? 0
    }
}
