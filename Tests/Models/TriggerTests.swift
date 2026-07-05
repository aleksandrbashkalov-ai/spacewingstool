import XCTest
@testable import Spacewingstool

final class TriggerTests: XCTestCase {
    func testAppRunningTrigger() {
        let trigger = SpaceTrigger.appRunning(bundleIDs: ["com.apple.dt.Xcode"])
        if case .appRunning(let bundleIDs) = trigger {
            XCTAssertEqual(bundleIDs, ["com.apple.dt.Xcode"])
        } else {
            XCTFail("Expected appRunning trigger")
        }
    }

    func testCalendarEventTrigger() {
        let trigger = SpaceTrigger.calendarEvent(keywords: ["meeting", "call"])
        if case .calendarEvent(let keywords) = trigger {
            XCTAssertEqual(keywords, ["meeting", "call"])
        } else {
            XCTFail("Expected calendarEvent trigger")
        }
    }

    func testManualTrigger() {
        let trigger = SpaceTrigger.manual
        XCTAssertEqual(trigger, .manual)
    }

    func testTimeRangeTrigger() {
        let now = Date()
        let start = now
        let end = now.addingTimeInterval(3600)
        let trigger = SpaceTrigger.timeRange(start: start, end: end)
        if case .timeRange(let s, let e) = trigger {
            XCTAssertEqual(s, start)
            XCTAssertEqual(e, end)
        } else {
            XCTFail("Expected timeRange trigger")
        }
    }

    func testUrlPatternTrigger() {
        let trigger = SpaceTrigger.urlPattern(pattern: "github.com")
        if case .urlPattern(let pattern) = trigger {
            XCTAssertEqual(pattern, "github.com")
        } else {
            XCTFail("Expected urlPattern trigger")
        }
    }

    func testFocusModeTrigger() {
        let trigger = SpaceTrigger.focusMode(name: "Focus")
        if case .focusMode(let name) = trigger {
            XCTAssertEqual(name, "Focus")
        } else {
            XCTFail("Expected focusMode trigger")
        }
    }

    func testTriggerCodable() throws {
        let trigger = SpaceTrigger.appRunning(bundleIDs: ["com.apple.dt.Xcode"])
        let data = try JSONEncoder().encode(trigger)
        let decoded = try JSONDecoder().decode(SpaceTrigger.self, from: data)
        XCTAssertEqual(trigger, decoded)
    }

    func testTriggerEquality() {
        let t1 = SpaceTrigger.appRunning(bundleIDs: ["com.apple.dt.Xcode"])
        let t2 = SpaceTrigger.appRunning(bundleIDs: ["com.apple.dt.Xcode"])
        let t3 = SpaceTrigger.appRunning(bundleIDs: ["com.apple.Safari"])
        XCTAssertEqual(t1, t2)
        XCTAssertNotEqual(t1, t3)
    }

    func testTriggerAllCases() {
        let triggers: [SpaceTrigger] = [
            .appRunning(bundleIDs: []),
            .timeRange(start: Date(), end: Date()),
            .urlPattern(pattern: ""),
            .focusMode(name: "")
        ]
        XCTAssertEqual(triggers.count, 4)
    }
}
