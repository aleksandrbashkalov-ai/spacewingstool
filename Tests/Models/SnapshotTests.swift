import XCTest
@testable import Spacewingstool

final class SnapshotTests: XCTestCase {
    func testSessionSnapshotDefaults() {
        let snapshot = SessionSnapshot(name: "Test Snapshot")
        XCTAssertEqual(snapshot.name, "Test Snapshot")
        XCTAssertFalse(snapshot.id.uuidString.isEmpty)
    }

    func testSessionSnapshotWithSpace() {
        let space = Space(name: "Test Space", mode: .coding)
        let snapshot = SessionSnapshot(name: "Test", spaceID: space.id, spaceName: space.name)
        XCTAssertEqual(snapshot.spaceName, "Test Space")
        XCTAssertEqual(snapshot.spaceID, space.id)
    }

    func testSessionSnapshotCodable() throws {
        let snapshot = SessionSnapshot(name: "Test Snapshot")
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)
        XCTAssertEqual(decoded.name, snapshot.name)
        XCTAssertEqual(decoded.id, snapshot.id)
    }

    func testProductivityStatsDefaults() {
        let stats = ProductivityStats(
            date: Date(),
            spaceName: "Test Space",
            appUsage: [:],
            contextSwitches: 0,
            productivityScore: 0.0
        )
        XCTAssertEqual(stats.spaceName, "Test Space")
        XCTAssertEqual(stats.productivityScore, 0.0)
    }

    func testProductivityStatsWithUsage() {
        let stats = ProductivityStats(
            date: Date(),
            spaceName: "Work",
            appUsage: ["com.apple.dt.Xcode": 3600, "com.apple.Safari": 600],
            contextSwitches: 3,
            productivityScore: 85.5
        )
        XCTAssertEqual(stats.spaceName, "Work")
        XCTAssertEqual(stats.productivityScore, 85.5)
        XCTAssertEqual(stats.contextSwitches, 3)
        XCTAssertEqual(stats.appUsage["com.apple.dt.Xcode"], 3600)
    }

    func testProductivityAnalysisValues() {
        let analysis = ProductivityAnalysis(
            productiveTime: 3600,
            distractionTime: 300,
            contextSwitches: 5,
            productivityScore: 80,
            suggestion: "Reduce context switches"
        )
        XCTAssertEqual(analysis.productiveTime, 3600)
        XCTAssertEqual(analysis.distractionTime, 300)
        XCTAssertEqual(analysis.productivityScore, 80)
        XCTAssertEqual(analysis.contextSwitches, 5)
    }
}
