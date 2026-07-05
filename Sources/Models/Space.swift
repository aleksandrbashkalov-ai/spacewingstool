import CoreGraphics
import Foundation

public enum SpaceMode: String, Codable, CaseIterable, Sendable {
    case deepWork = "Deep Work"
    case creative = "Creative"
    case meetings = "Meetings"
    case coding = "Coding"
    case browsing = "Browsing"
    case custom = "Custom"
}

public enum SpaceTrigger: Codable, Equatable, Sendable {
    case appRunning(bundleIDs: Set<String>)
    case urlPattern(pattern: String)
    case timeRange(start: Date, end: Date)
    case calendarEvent(keywords: [String])
    case focusMode(name: String)
    case manual
}

extension SpaceTrigger: Identifiable {
    public var id: String {
        switch self {
        case .appRunning: "appRunning"
        case .urlPattern: "urlPattern"
        case .timeRange: "timeRange"
        case .calendarEvent: "calendarEvent"
        case .focusMode: "focusMode"
        case .manual: "manual"
        }
    }
}

public struct AppLayout: Codable, Equatable, Sendable {
    public var bundleID: String
    public var frame: CGRect
    public var isFrontmost: Bool
    public var tabURLs: [String]
    public var windowTitle: String

    public init(bundleID: String, frame: CGRect = .zero, isFrontmost: Bool = false, tabURLs: [String] = [], windowTitle: String = "") {
        self.bundleID = bundleID
        self.frame = frame
        self.isFrontmost = isFrontmost
        self.tabURLs = tabURLs
        self.windowTitle = windowTitle
    }
}

public struct Space: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var mode: SpaceMode
    public var isActive: Bool
    public var createdAt: Date
    public var lastUsedAt: Date?
    public var useCount: Int
    public var iconName: String
    public var triggers: [SpaceTrigger]
    public var appLayouts: [AppLayout]
    public var notes: String
    public var isFavorite: Bool
    public var color: String

    public init(
        id: UUID = UUID(),
        name: String,
        mode: SpaceMode = .custom,
        isActive: Bool = false,
        createdAt: Date = Date(),
        iconName: String = "square.split.2x2",
        triggers: [SpaceTrigger] = [],
        appLayouts: [AppLayout] = [],
        notes: String = "",
        isFavorite: Bool = false,
        color: String = "blue"
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastUsedAt = nil
        self.useCount = 0
        self.iconName = iconName
        self.triggers = triggers
        self.appLayouts = appLayouts
        self.notes = notes
        self.isFavorite = isFavorite
        self.color = color
    }

    public static var defaultSpaces: [Space] {
        let now = Date()
        let cal = Calendar.current
        let nineAM = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let twelvePM = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        return [
            Space(
                name: "Deep Work",
                mode: .deepWork,
                iconName: "brain.head.profile",
                triggers: [.focusMode(name: "Focus"), .timeRange(start: nineAM, end: twelvePM)],
                color: "purple"
            ),
            Space(
                name: "Coding",
                mode: .coding,
                iconName: "chevron.left.forwardslash.chevron.right",
                triggers: [.appRunning(bundleIDs: ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.jetbrains.intellij"])],
                color: "blue"
            ),
            Space(
                name: "Meetings",
                mode: .meetings,
                iconName: "video",
                triggers: [.appRunning(bundleIDs: ["us.zoom.xos", "com.apple.facetime", "com.microsoft.teams2", "com.google.Chrome"]), .calendarEvent(keywords: ["meeting", "call", "sync"])],
                color: "orange"
            ),
            Space(
                name: "Creative",
                mode: .creative,
                iconName: "paintbrush.pointed",
                triggers: [.appRunning(bundleIDs: ["com.apple.finalcutpro", "com.seriflabs.affinityphoto2", "com.adobe.illustrator"])],
                color: "pink"
            ),
        ]
    }
}
