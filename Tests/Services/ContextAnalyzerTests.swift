import XCTest
@testable import Spacewingstool

final class ContextAnalyzerTests: XCTestCase {
    func testSharedInstance() {
        let analyzer = ContextAnalyzer.shared
        XCTAssertNotNil(analyzer)
    }

    func testTimeOfDayCurrent() {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = TimeOfDay.current()

        switch hour {
        case 0..<6: XCTAssertEqual(timeOfDay, .night)
        case 6..<9: XCTAssertEqual(timeOfDay, .earlyMorning)
        case 9..<12: XCTAssertEqual(timeOfDay, .morning)
        case 12..<17: XCTAssertEqual(timeOfDay, .afternoon)
        case 17..<22: XCTAssertEqual(timeOfDay, .evening)
        default: XCTAssertEqual(timeOfDay, .night)
        }
    }

    func testProductivityLevels() {
        let levels: [ProductivityLevel] = [.focused, .neutral, .distracted, .idle]
        XCTAssertEqual(levels.count, 4)
    }

    func testCalendarEventInit() {
        let now = Date()
        let event = CalendarEvent(
            id: "test-1",
            title: "Test Meeting",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: "Work"
        )

        XCTAssertEqual(event.title, "Test Meeting")
        XCTAssertEqual(event.calendarTitle, "Work")
    }

    func testGetLastContextInitial() async {
        let analyzer = ContextAnalyzer.shared
        let context = await analyzer.getLastContext()
        XCTAssertNil(context)
    }

    func testDetectedContextDefaults() {
        let context = DetectedContext()
        XCTAssertTrue(context.activeApps.isEmpty)
        XCTAssertEqual(context.productivityEstimate, .neutral)
        XCTAssertEqual(context.confidence, 0.0)
        XCTAssertEqual(context.timeOfDay, .morning)
    }

    func testTimeOfDayAllCases() {
        let cases = TimeOfDay.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.earlyMorning))
        XCTAssertTrue(cases.contains(.morning))
        XCTAssertTrue(cases.contains(.afternoon))
        XCTAssertTrue(cases.contains(.evening))
        XCTAssertTrue(cases.contains(.night))
    }

    func testAppWindowInfoInit() {
        let info = AppWindowInfo(bundleID: "com.test.app", appName: "Test")
        XCTAssertEqual(info.bundleID, "com.test.app")
        XCTAssertEqual(info.appName, "Test")
        XCTAssertFalse(info.isOnTop)
        XCTAssertFalse(info.isMinimized)
    }
}
