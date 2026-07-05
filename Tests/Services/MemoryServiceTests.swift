import XCTest
@testable import Spacewingstool

final class MemoryServiceTests: XCTestCase {
    func testSharedInstance() {
        let service = MemoryService.shared
        XCTAssertNotNil(service)
    }

    func testSnapshotRoundtrip() async {
        let service = MemoryService.shared
        let space = Space(name: "Test Space", mode: .coding)
        let snapshot = await service.saveSnapshot(name: "Test Snapshot", space: space)

        XCTAssertEqual(snapshot.name, "Test Snapshot")
        XCTAssertEqual(snapshot.spaceName, "Test Space")

        await service.deleteSnapshot(snapshot)
    }

    func testDeleteSnapshot() async {
        let service = MemoryService.shared
        let snapshot = await service.saveSnapshot(name: "Delete Test", space: nil)
        await service.deleteSnapshot(snapshot)

        let all = await service.loadAllSnapshots()
        XCTAssertFalse(all.contains(where: { $0.id == snapshot.id }))
    }

    func testLoadSnapshotsLimit() async {
        let service = MemoryService.shared
        let snapshots = await service.loadSnapshots(limit: 5)
        XCTAssertLessThanOrEqual(snapshots.count, 5)
    }

    func testProductivityRoundtrip() async {
        let service = MemoryService.shared
        await service.logProductivity(
            date: Date(),
            spaceName: "Test",
            timeSpent: 3600,
            appUsage: ["com.apple.dt.Xcode": 3600],
            contextSwitches: 2,
            productivityScore: 85.0
        )

        let history = await service.loadAllProductivity()
        let latest = history.last
        XCTAssertEqual(latest?.spaceName, "Test")
        XCTAssertEqual(latest?.productivityScore, 85.0)
    }

    func testProductivityHistory() async {
        let service = MemoryService.shared
        let history = await service.getProductivityHistory(days: 7)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        XCTAssertTrue(history.allSatisfy { $0.date >= sevenDaysAgo })
    }
}
