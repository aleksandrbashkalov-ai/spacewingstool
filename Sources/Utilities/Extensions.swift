import AppKit
import Foundation
import SwiftUI

public extension NSImage {
    static func systemSymbol(_ name: String, accessibilityDescription: String? = nil) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) ?? NSImage()
    }
}

public extension Array where Element: Equatable {
    func unique() -> [Element] {
        var result: [Element] = []
        for element in self {
            if !result.contains(element) {
                result.append(element)
            }
        }
        return result
    }

    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

public extension NSWorkspace {
    func isAppRunning(bundleID: String) -> Bool {
        runningApplications.contains { $0.bundleIdentifier == bundleID }
    }
}

// MARK: - TimeInterval Formatting

public extension TimeInterval {
    /// Formats a time interval as a human-readable duration string (e.g. "2h 30m" or "45m").
    func formatDuration() -> String {
        let hours = Int(self / 3600)
        let minutes = Int((self.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Coaching Colors

public extension Color {
    static func burnoutColor(_ level: BurnoutRiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    static func priorityColor(_ priority: AdvicePriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}
