import XCTest
@testable import Spacewingstool

final class SettingsStoreTests: XCTestCase {
    @MainActor
    func testSharedInstance() {
        let store = SettingsStore.shared
        XCTAssertNotNil(store)
    }

    @MainActor
    func testDefaultValues() {
        let store = SettingsStore.shared
        XCTAssertTrue(store.isAutoSwitchEnabled)
        XCTAssertEqual(store.pollingInterval, 2.0)
        XCTAssertTrue(store.showMiniMap)
        XCTAssertTrue(store.showMenuBarIcon)
        XCTAssertTrue(store.showNotifications)
        XCTAssertEqual(store.snapshotRetentionDays, 30)
    }

    @MainActor
    func testToggleAutoSwitch() {
        let store = SettingsStore.shared
        let original = store.isAutoSwitchEnabled
        store.isAutoSwitchEnabled.toggle()
        XCTAssertNotEqual(store.isAutoSwitchEnabled, original)
        store.isAutoSwitchEnabled = original
    }

    @MainActor
    func testResetToDefaults() {
        let store = SettingsStore.shared
        store.resetToDefaults()
        XCTAssertTrue(store.isAutoSwitchEnabled)
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertEqual(store.pollingInterval, 2.0)
        XCTAssertEqual(store.snapshotRetentionDays, 30)
    }

    @MainActor
    func testPollingInterval() {
        let store = SettingsStore.shared
        let original = store.pollingInterval
        store.pollingInterval = 3.0
        XCTAssertEqual(store.pollingInterval, 3.0)
        store.pollingInterval = original
    }
}
