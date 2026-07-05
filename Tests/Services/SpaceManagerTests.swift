import XCTest
@testable import Spacewingstool

final class SpaceManagerTests: XCTestCase {
    @MainActor
    func testSharedInstance() {
        let store = SpaceStore.shared
        XCTAssertNotNil(store)
    }

    @MainActor
    func testEvaluateContextAppRunning() {
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
            activeApps: ["com.apple.dt.Xcode", "com.apple.Safari"],
            frontmostApp: "com.apple.dt.Xcode"
        )

        store.evaluateContext(context)

        XCTAssertEqual(store.suggestedSpace?.name, "Coding")
    }

    @MainActor
    func testEvaluateContextNoMatch() {
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
            activeApps: ["com.apple.Safari"],
            frontmostApp: "com.apple.Safari"
        )

        store.evaluateContext(context)

        XCTAssertNil(store.suggestedSpace)
    }

    @MainActor
    func testEvaluateContextDisabled() {
        let store = SpaceStore.shared
        store.isAutoSwitchEnabled = false

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

        XCTAssertNil(store.suggestedSpace)
    }

    @MainActor
    func testActivateSpace() {
        let store = SpaceStore.shared
        let space = Space(name: "Test Space", mode: .coding)
        store.spaces.append(space)

        store.activateSpace(space)

        XCTAssertEqual(store.activeSpace?.id, space.id)
    }

    @MainActor
    func testAddAndRemoveSpace() {
        let store = SpaceStore.shared
        let initialCount = store.spaces.count

        store.addSpace(name: "Test Space", mode: .coding)
        XCTAssertEqual(store.spaces.count, initialCount + 1)

        if let added = store.spaces.last {
            store.removeSpace(added)
            XCTAssertEqual(store.spaces.count, initialCount)
        }
    }
}
