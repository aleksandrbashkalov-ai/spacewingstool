import Foundation
import AppKit

public protocol AIServiceProtocol: Sendable {
    func initialize()
    var isReady: Bool { get }
    func classifyActivity(appIDs: [String], windowTitles: [String], urls: [String]) -> SpaceMode?
    func suggestSpaceName(from apps: [String], windowTitles: [String]) -> String
    func extractEntities(from text: String) -> [String]
    func analyzeProductivity(appUsage: [String: TimeInterval], contextSwitches: Int, totalTime: TimeInterval) -> ProductivityAnalysis
}

public protocol ContextAnalyzerProtocol: Sendable {
    func startAnalysis()
    func requestCalendarAccess() async
    func getLastContext() -> DetectedContext?
}

public protocol MemoryServiceProtocol: Sendable {
    func saveSnapshot(name: String, space: Space?) async -> SessionSnapshot
    func loadAllSnapshots() async -> [SessionSnapshot]
    func loadSnapshots(limit: Int) async -> [SessionSnapshot]
    func deleteSnapshot(_ snapshot: SessionSnapshot) async
    func restoreSnapshot(_ snapshot: SessionSnapshot)
    func logProductivity(date: Date, spaceName: String, timeSpent: TimeInterval, appUsage: [String: TimeInterval], contextSwitches: Int, productivityScore: Double) async
    func loadAllProductivity() async -> [ProductivityStats]
    func getProductivityHistory(days: Int) async -> [ProductivityStats]
}

public protocol WindowMonitorProtocol: Sendable {
    var isAccessibilityAuthorized: Bool { get }
    func startMonitoring(interval: TimeInterval)
    func stopMonitoring()
    func setPollingInterval(_ interval: TimeInterval)
    func scanWindows()
    func getActiveAppID() -> String
    func getActiveAppName() -> String
    func getRunningAppIDs() -> [String]
    func getFrontmostApp() -> NSRunningApplication?
    func getFrontmostWindowTitle() -> String
    func clearCache()
    func requestAccessibilityPermission()
}

public protocol PersistenceServiceProtocol: Sendable {
    func save<T: Codable>(_ value: T, key: String)
    func load<T: Codable>(_ type: T.Type, key: String) -> T?
    func delete(key: String)
}

public protocol SettingsStoreProtocol: AnyObject {
    var isAutoSwitchEnabled: Bool { get set }
    var launchAtLogin: Bool { get set }
    var pollingInterval: Double { get set }
    var showMiniMap: Bool { get set }
    var showMenuBarIcon: Bool { get set }
    var showNotifications: Bool { get set }
    var snapshotRetentionDays: Int { get set }
    func resetToDefaults()
}

public protocol SpaceStoreProtocol: AnyObject {
    var spaces: [Space] { get set }
    var activeSpace: Space? { get set }
    var isAutoSwitchEnabled: Bool { get set }
    var suggestedSpace: Space? { get set }
    func loadSpaces() async
    func activateSpace(_ space: Space)
    func deactivateCurrentSpace()
    func addSpace(name: String, mode: SpaceMode)
    func removeSpace(_ space: Space)
    func toggleFavorite(_ space: Space)
    func updateSpace(_ space: Space)
    func evaluateContext(_ context: DetectedContext)
    func snapshotCurrentLayout(for space: inout Space)
}
