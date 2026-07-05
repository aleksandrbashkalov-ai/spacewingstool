import XCTest
@testable import Spacewingstool

final class AIServiceTests: XCTestCase {
    func testClassifyCoding() async {
        let service = AIService.shared
        let mode = await service.classifyActivity(
            appIDs: ["com.apple.dt.Xcode"],
            windowTitles: ["main.swift"],
            urls: []
        )
        XCTAssertEqual(mode, .coding)
    }

    func testClassifyMeetings() async {
        let service = AIService.shared
        let mode = await service.classifyActivity(
            appIDs: ["us.zoom.xos"],
            windowTitles: ["Meeting"],
            urls: []
        )
        XCTAssertEqual(mode, .meetings)
    }

    func testClassifyUnknown() async {
        let service = AIService.shared
        let mode = await service.classifyActivity(
            appIDs: ["com.apple.Calculator"],
            windowTitles: [],
            urls: []
        )
        XCTAssertNil(mode)
    }

    func testSuggestSpaceName() async {
        let service = AIService.shared
        let name = await service.suggestSpaceName(
            from: ["com.apple.dt.Xcode"],
            windowTitles: ["test.swift"]
        )
        XCTAssertEqual(name, "Coding Session")
    }

    func testAnalyzeProductivity() async {
        let service = AIService.shared
        let result = await service.analyzeProductivity(
            appUsage: ["com.apple.dt.Xcode": 3600],
            contextSwitches: 2,
            totalTime: 3600
        )
        XCTAssertEqual(result.productiveTime, 3600)
        XCTAssertEqual(result.distractionTime, 0)
        XCTAssertGreaterThan(result.productivityScore, 0)
    }

    func testExtractEntities() async {
        let service = AIService.shared
        await service.initialize()
        let entities = await service.extractEntities(from: "hello world")
        XCTAssertTrue(entities.isEmpty)
    }

    func testClassifyCreative() async {
        let service = AIService.shared
        let mode = await service.classifyActivity(
            appIDs: ["com.adobe.illustrator"],
            windowTitles: ["design.ai"],
            urls: []
        )
        XCTAssertEqual(mode, .creative)
    }

    func testClassifyBrowsing() async {
        let service = AIService.shared
        let mode = await service.classifyActivity(
            appIDs: ["com.apple.Safari"],
            windowTitles: [],
            urls: ["https://github.com"]
        )
        XCTAssertEqual(mode, .browsing)
    }
}
