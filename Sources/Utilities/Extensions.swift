import AppKit
import Foundation

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
