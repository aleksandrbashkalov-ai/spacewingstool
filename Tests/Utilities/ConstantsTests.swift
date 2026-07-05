import XCTest
@testable import Spacewingstool

final class ConstantsTests: XCTestCase {
    func testAppName() {
        XCTAssertEqual(Constants.appName, "Spacewingstool")
    }

    func testAppBundleID() {
        XCTAssertEqual(Constants.appBundleID, "com.spacewingstool.app")
    }

    func testDefaultPollingInterval() {
        XCTAssertEqual(Constants.defaultPollingInterval, 2.0)
    }

    func testMaxSnapshotCount() {
        XCTAssertEqual(Constants.maxSnapshotCount, 50)
    }

    func testSnapshotRetentionDays() {
        XCTAssertEqual(Constants.defaultSnapshotRetentionDays, 30)
        XCTAssertEqual(Constants.maxSnapshotRetentionDays, 90)
    }
}
