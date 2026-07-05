import XCTest
@testable import Spacewingstool

final class SpaceStoreTests: XCTestCase {
    @MainActor
    func testSharedInstance() {
        let store = SpaceStore.shared
        XCTAssertNotNil(store)
    }

    @MainActor
    func testAddSpace() {
        let store = SpaceStore.shared
        let initialCount = store.spaces.count

        store.addSpace(name: "Test Space", mode: .coding)

        XCTAssertEqual(store.spaces.count, initialCount + 1)
        XCTAssertEqual(store.spaces.last?.name, "Test Space")
    }

    @MainActor
    func testActivateSpace() {
        let store = SpaceStore.shared
        let testSpace = Space(name: "Test", mode: .coding)
        store.spaces.append(testSpace)

        store.activateSpace(testSpace)

        XCTAssertEqual(store.activeSpace?.id, testSpace.id)
        XCTAssertTrue(store.spaces.first(where: { $0.id == testSpace.id })?.isActive == true)
    }

    @MainActor
    func testDeactivateCurrentSpace() {
        let store = SpaceStore.shared
        let testSpace = Space(name: "Test", mode: .coding, isActive: true)
        store.spaces.append(testSpace)
        store.activeSpace = testSpace

        store.deactivateCurrentSpace()

        XCTAssertNil(store.activeSpace)
        XCTAssertFalse(store.spaces.first(where: { $0.id == testSpace.id })?.isActive == true)
    }

    @MainActor
    func testToggleFavorite() {
        let store = SpaceStore.shared
        let testSpace = Space(name: "Test", mode: .coding, isFavorite: false)
        store.spaces.append(testSpace)

        store.toggleFavorite(testSpace)

        XCTAssertTrue(store.spaces.first(where: { $0.id == testSpace.id })?.isFavorite == true)

        store.toggleFavorite(testSpace)
        XCTAssertFalse(store.spaces.first(where: { $0.id == testSpace.id })?.isFavorite == true)
    }

    @MainActor
    func testEvaluateContext() {
        let store = SpaceStore.shared
        store.isAutoSwitchEnabled = true

        let space = Space(
            name: "Coding",
            mode: .coding,
            triggers: [.appRunning(bundleIDs: ["com.apple.dt.Xcode"])]
        )
        store.spaces = [space]
        store.suggestedSpace = nil

        let context = DetectedContext(
            activeApps: ["com.apple.dt.Xcode"],
            frontmostApp: "com.apple.dt.Xcode"
        )

        store.evaluateContext(context)

        XCTAssertEqual(store.suggestedSpace?.name, "Coding")
    }

    @MainActor
    func testEvaluateContextDisabled() {
        let store = SpaceStore.shared
        store.suggestedSpace = nil
        store.isAutoSwitchEnabled = false

        let space = Space(
            name: "Coding",
            mode: .coding,
            triggers: [.appRunning(bundleIDs: ["com.apple.dt.Xcode"])]
        )
        store.spaces = [space]

        let context = DetectedContext(
            activeApps: ["com.apple.dt.Xcode"],
            frontmostApp: "com.apple.dt.Xcode"
        )

        store.evaluateContext(context)

        XCTAssertNil(store.suggestedSpace)
    }
}
