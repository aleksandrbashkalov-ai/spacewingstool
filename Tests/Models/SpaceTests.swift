import XCTest
@testable import Spacewingstool

final class SpaceTests: XCTestCase {
    func testSpaceDefaults() {
        let space = Space(name: "Test Space", mode: .coding)
        XCTAssertEqual(space.name, "Test Space")
        XCTAssertEqual(space.mode, .coding)
        XCTAssertFalse(space.isActive)
        XCTAssertFalse(space.isFavorite)
        XCTAssertTrue(space.triggers.isEmpty)
        XCTAssertFalse(space.id.uuidString.isEmpty)
    }

    func testSpaceCustomInit() {
        let space = Space(
            name: "Work",
            mode: SpaceMode.deepWork,
            isActive: true,
            triggers: [SpaceTrigger.appRunning(bundleIDs: ["com.apple.dt.Xcode"])],
            isFavorite: true
        )
        XCTAssertEqual(space.name, "Work")
        XCTAssertEqual(space.mode, SpaceMode.deepWork)
        XCTAssertTrue(space.isActive)
        XCTAssertTrue(space.isFavorite)
        XCTAssertEqual(space.triggers.count, 1)
    }

    func testSpaceEquality() {
        let space1 = Space(name: "Test", mode: .coding)
        let space2 = Space(name: "Test", mode: .coding)
        XCTAssertEqual(space1.id, space1.id)
        XCTAssertNotEqual(space1.id, space2.id)
    }

    func testSpaceModeCases() {
        XCTAssertEqual(SpaceMode.allCases.count, 6)
        XCTAssertTrue(SpaceMode.allCases.contains(.coding))
        XCTAssertTrue(SpaceMode.allCases.contains(.deepWork))
        XCTAssertTrue(SpaceMode.allCases.contains(.meetings))
        XCTAssertTrue(SpaceMode.allCases.contains(.creative))
        XCTAssertTrue(SpaceMode.allCases.contains(.browsing))
        XCTAssertTrue(SpaceMode.allCases.contains(.custom))
    }
}
