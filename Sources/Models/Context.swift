import CoreGraphics
import Foundation

public struct AccessibilityNode: Codable, Equatable, Sendable {
    public var role: String
    public var title: String?
    public var value: String?
    public var description: String?
    public var isEnabled: Bool
    public var isFocused: Bool
    public var frame: CGRect
    public var children: [AccessibilityNode]
    public var url: String?

    public init(
        role: String,
        title: String? = nil,
        value: String? = nil,
        description: String? = nil,
        isEnabled: Bool = true,
        isFocused: Bool = false,
        frame: CGRect = .zero,
        children: [AccessibilityNode] = [],
        url: String? = nil
    ) {
        self.role = role
        self.title = title
        self.value = value
        self.description = description
        self.isEnabled = isEnabled
        self.isFocused = isFocused
        self.frame = frame
        self.children = children
        self.url = url
    }
}

public struct AppDeepContext: Codable, Equatable, Sendable {
    public var bundleID: String
    public var appName: String
    public var windowTitle: String
    public var uiTree: AccessibilityNode?
    public var focusedElement: AccessibilityNode?
    public var tabs: [String]
    public var urls: [String]
    public var activeFile: String?
    public var uiState: String?

    public init(
        bundleID: String,
        appName: String,
        windowTitle: String = "",
        uiTree: AccessibilityNode? = nil,
        focusedElement: AccessibilityNode? = nil,
        tabs: [String] = [],
        urls: [String] = [],
        activeFile: String? = nil,
        uiState: String? = nil
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.uiTree = uiTree
        self.focusedElement = focusedElement
        self.tabs = tabs
        self.urls = urls
        self.activeFile = activeFile
        self.uiState = uiState
    }
}

public enum ProductivityLevel: String, Codable, Sendable {
    case focused = "Focused"
    case neutral = "Neutral"
    case distracted = "Distracted"
    case idle = "Idle"
}

public struct DetectedContext: Codable, Equatable, Sendable {
    public var activeApps: [String]
    public var frontmostApp: String
    public var frontmostWindowTitle: String
    public var activeURLs: [String]
    public var timeOfDay: TimeOfDay
    public var focusMode: String?
    public var calendarEvents: [CalendarEvent]
    public var productivityEstimate: ProductivityLevel
    public var suggestedSpaceMode: SpaceMode?
    public var confidence: Double
    public var appDeepContexts: [String: AppDeepContext]
    public var activeWindowUI: AccessibilityNode?

    public init(
        activeApps: [String] = [],
        frontmostApp: String = "",
        frontmostWindowTitle: String = "",
        activeURLs: [String] = [],
        timeOfDay: TimeOfDay = .morning,
        focusMode: String? = nil,
        calendarEvents: [CalendarEvent] = [],
        productivityEstimate: ProductivityLevel = .neutral,
        suggestedSpaceMode: SpaceMode? = nil,
        confidence: Double = 0.0,
        appDeepContexts: [String: AppDeepContext] = [:],
        activeWindowUI: AccessibilityNode? = nil
    ) {
        self.activeApps = activeApps
        self.frontmostApp = frontmostApp
        self.frontmostWindowTitle = frontmostWindowTitle
        self.activeURLs = activeURLs
        self.timeOfDay = timeOfDay
        self.focusMode = focusMode
        self.calendarEvents = calendarEvents
        self.productivityEstimate = productivityEstimate
        self.suggestedSpaceMode = suggestedSpaceMode
        self.confidence = confidence
        self.appDeepContexts = appDeepContexts
        self.activeWindowUI = activeWindowUI
    }
}

public enum TimeOfDay: String, Codable, CaseIterable, Sendable {
    case earlyMorning = "Early Morning"
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    public static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return .night
        case 6..<9: return .earlyMorning
        case 9..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    public var symbolName: String {
        switch self {
        case .earlyMorning: "sunrise"
        case .morning: "sun.max"
        case .afternoon: "sun.horizon"
        case .evening: "moon.stars"
        case .night: "moon"
        }
    }
}

public struct CalendarEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var calendarTitle: String

    public init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isAllDay: Bool = false, calendarTitle: String = "") {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
    }
}

public struct AppWindowInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bundleID: String
    public var appName: String
    public var windowTitle: String
    public var frame: CGRect
    public var isOnTop: Bool
    public var isMinimized: Bool
    public var tabs: [String]

    public init(id: UUID = UUID(), bundleID: String, appName: String, windowTitle: String = "", frame: CGRect = .zero, isOnTop: Bool = false, isMinimized: Bool = false, tabs: [String] = []) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.frame = frame
        self.isOnTop = isOnTop
        self.isMinimized = isMinimized
        self.tabs = tabs
    }
}
