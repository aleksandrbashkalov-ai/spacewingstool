import Foundation
import GRDB

public struct ActivityDatabase {
    private let dbQueue: DatabaseQueue

    public init(url: URL) throws {
        let queue = try DatabaseQueue(path: url.path)
        self.dbQueue = queue
        try migrator.migrate(queue)
    }

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Schema

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "activity_record", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("activityType", .text).notNull().indexed()
                t.column("category", .text).indexed()
                t.column("appBundleID", .text).indexed()
                t.column("appName", .text)
                t.column("title", .text)
                t.column("contentExcerpt", .text)
                t.column("metadataJSON", .text)
                t.column("duration", .double).defaults(to: 0)
                t.column("confidence", .double).defaults(to: 1.0)
                t.column("source", .text).notNull()
                t.column("isSummarized", .boolean).defaults(to: false)
                t.column("summaryID", .text)
                t.column("sessionID", .text).indexed()
            }

            try db.create(table: "activity_summary", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("periodStart", .datetime).notNull()
                t.column("periodEnd", .datetime).notNull()
                t.column("summaryType", .text).notNull()
                t.column("title", .text).notNull()
                t.column("summaryText", .text).notNull()
                t.column("keyPoints", .text)
                t.column("activityTypeBreakdown", .text)
                t.column("aiGenerated", .boolean).defaults(to: false)
                t.column("providerID", .text)
            }

            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS activity_fts USING fts5(
                    title, contentExcerpt, category, activityType,
                    content=activity_record,
                    content_rowid=rowid
                )
            """)

            try db.create(table: "settings_snapshot", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("label", .text)
                t.column("settingsJSON", .text).notNull()
                t.column("source", .text).notNull()
                t.column("aiSuggestionID", .text)
            }
        }

        // v2 removed — settings_snapshot table already created in v1

        migrator.registerMigration("v2_signal_weight") { db in
            try db.alter(table: "activity_record") { t in
                t.add(column: "signalWeight", .text)
            }
        }
        return migrator
    }

    // MARK: - Insert

    public func insert(_ record: ActivityRecord) throws {
        try dbQueue.write { db in
            try performInsert(db, record: record)
        }
    }

    public func insertBatch(_ records: [ActivityRecord]) throws {
        try dbQueue.write { db in
            for record in records {
                try performInsert(db, record: record)
            }
        }
    }

    // MARK: - Query

    public func records(in range: ClosedRange<Date>, limit: Int = 200, offset: Int = 0) throws -> [ActivityRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM activity_record
                WHERE timestamp >= ? AND timestamp <= ?
                ORDER BY timestamp DESC
                LIMIT ? OFFSET ?
            """, arguments: [range.lowerBound, range.upperBound, limit, offset])
            return rows.compactMap { decode($0) }
        }
    }

    public func records(type: ActivityType, limit: Int = 100) throws -> [ActivityRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM activity_record
                WHERE activityType = ?
                ORDER BY timestamp DESC
                LIMIT ?
            """, arguments: [type.rawValue, limit])
            return rows.compactMap { decode($0) }
        }
    }

    public func records(sessionID: String) throws -> [ActivityRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM activity_record
                WHERE sessionID = ?
                ORDER BY timestamp
            """, arguments: [sessionID])
            return rows.compactMap { decode($0) }
        }
    }

    public func recentRecords(hours: Int = 24) throws -> [ActivityRecord] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(hours) * 3600)
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM activity_record
                WHERE timestamp >= ?
                ORDER BY timestamp DESC
            """, arguments: [cutoff])
            return rows.compactMap { decode($0) }
        }
    }

    public func activityTypeSummary(in range: ClosedRange<Date>) throws -> [(ActivityType, TimeInterval)] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT activityType, SUM(duration) as totalDuration
                FROM activity_record
                WHERE timestamp >= ? AND timestamp <= ?
                GROUP BY activityType
                ORDER BY totalDuration DESC
            """, arguments: [range.lowerBound, range.upperBound])

            return rows.compactMap { row in
                guard let raw = row["activityType"] as String?,
                      let type = ActivityType(rawValue: raw),
                      let dur = row["totalDuration"] as Double? else { return nil }
                return (type, dur)
            }
        }
    }

    // MARK: - Search

    public func search(term: String, limit: Int = 50) throws -> [ActivityRecord] {
        try dbQueue.read { db in
            let ftsRows = try Row.fetchAll(db, sql: """
                SELECT rowid FROM activity_fts
                WHERE activity_fts MATCH ?
                ORDER BY rank
                LIMIT ?
            """, arguments: [term, limit])

            let rowIDs = ftsRows.compactMap { $0["rowid"] as? Int64 }
            guard !rowIDs.isEmpty else { return [] }

            let placeholders = rowIDs.map { _ in "?" }.joined(separator: ",")
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM activity_record
                WHERE rowid IN (\(placeholders))
            """, arguments: StatementArguments(rowIDs))
            return rows.compactMap { decode($0) }
        }
    }

    // MARK: - Settings Snapshots

    public func insertSnapshot(_ snapshot: SettingsSnapshot) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO settings_snapshot
                (id, timestamp, label, settingsJSON, source, aiSuggestionID)
                VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [
                snapshot.id, snapshot.timestamp, snapshot.label,
                snapshot.settingsJSON, snapshot.source.rawValue,
                snapshot.aiSuggestionID
            ])
        }
    }

    public func snapshots(limit: Int = 50, offset: Int = 0) throws -> [SettingsSnapshot] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM settings_snapshot
                ORDER BY timestamp DESC
                LIMIT ? OFFSET ?
            """, arguments: [limit, offset])
            return rows.compactMap { decodeSnapshot($0) }
        }
    }

    public func snapshot(id: String) throws -> SettingsSnapshot? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT * FROM settings_snapshot WHERE id = ?
            """, arguments: [id])
            return row.flatMap { decodeSnapshot($0) }
        }
    }

    public func deleteSnapshot(id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM settings_snapshot WHERE id = ?", arguments: [id])
        }
    }

    public func snapshotCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM settings_snapshot") ?? 0
        }
    }

    public func pruneSnapshots(keepLast: Int = 100) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                DELETE FROM settings_snapshot WHERE id NOT IN (
                    SELECT id FROM settings_snapshot ORDER BY timestamp DESC LIMIT ?
                )
            """, arguments: [keepLast])
        }
    }

    private func decodeSnapshot(_ row: Row) -> SettingsSnapshot? {
        guard let id = row["id"] as String?,
              let timestamp = row["timestamp"] as Date?,
              let settingsJSON = row["settingsJSON"] as String?,
              let rawSource = row["source"] as String?,
              let source = SnapshotSource(rawValue: rawSource) else { return nil }
        return SettingsSnapshot(
            id: id, timestamp: timestamp, label: row["label"] as String?,
            settingsJSON: settingsJSON, source: source,
            aiSuggestionID: row["aiSuggestionID"] as String?
        )
    }

    // MARK: - Maintenance

    public func deleteAll() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM activity_record")
            try db.execute(sql: "DELETE FROM activity_summary")
            try db.execute(sql: "DELETE FROM settings_snapshot")
            try db.execute(sql: "INSERT INTO activity_fts(activity_fts) VALUES('rebuild')")
        }
    }

    @discardableResult
    public func deleteOlderThan(_ date: Date) throws -> Int {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM activity_record WHERE timestamp < ?", arguments: [date])
            let deleted = db.changesCount
            try db.execute(sql: "DELETE FROM activity_summary WHERE periodEnd < ?", arguments: [date])
            try db.execute(sql: "INSERT INTO activity_fts(activity_fts) VALUES('rebuild')")
            return deleted
        }
    }

    public func recordCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM activity_record") ?? 0
        }
    }

    public func databaseSize() throws -> UInt64 {
        let url = URL(fileURLWithPath: dbQueue.path)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? UInt64 ?? 0
    }

    // MARK: - Private

    private func performInsert(_ db: Database, record: ActivityRecord) throws {
        try db.execute(sql: """
            INSERT OR REPLACE INTO activity_record
            (id, timestamp, activityType, category, appBundleID, appName, title, contentExcerpt,
             metadataJSON, duration, confidence, source, isSummarized, summaryID, sessionID, signalWeight)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [
            record.id, record.timestamp, record.activityType.rawValue,
            record.category, record.appBundleID, record.appName, record.title,
            record.contentExcerpt, record.metadataJSON, record.duration,
            record.confidence, record.source, record.isSummarized,
            record.summaryID, record.sessionID, record.signalWeight
        ])

        if let rowID = try Int64.fetchOne(db, sql: "SELECT rowid FROM activity_record WHERE id = ?", arguments: [record.id]) {
            try db.execute(sql: """
                INSERT INTO activity_fts(rowid, title, contentExcerpt, category, activityType)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                rowID, record.title ?? "", record.contentExcerpt ?? "",
                record.category ?? "", record.activityType.rawValue
            ])
        }
    }

    private func decode(_ row: Row) -> ActivityRecord? {
        guard let id = row["id"] as String?,
              let timestamp = row["timestamp"] as Date?,
              let rawType = row["activityType"] as String?,
              let type = ActivityType(rawValue: rawType),
              let source = row["source"] as String? else { return nil }

        return ActivityRecord(
            id: id,
            timestamp: timestamp,
            activityType: type,
            category: row["category"] as String?,
            appBundleID: row["appBundleID"] as String?,
            appName: row["appName"] as String?,
            title: row["title"] as String?,
            contentExcerpt: row["contentExcerpt"] as String?,
            metadataJSON: row["metadataJSON"] as String?,
            duration: row["duration"] as Double? ?? 0,
            confidence: row["confidence"] as Double? ?? 1.0,
            source: source,
            isSummarized: row["isSummarized"] as Bool? ?? false,
            summaryID: row["summaryID"] as String?,
            sessionID: row["sessionID"] as String?,
            signalWeight: row["signalWeight"] as String?
        )
    }
}
