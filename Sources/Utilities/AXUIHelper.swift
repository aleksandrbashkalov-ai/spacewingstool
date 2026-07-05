import AppKit
import ApplicationServices

@MainActor
enum AXUIHelper {
    static func getAttribute(element: AXUIElement, attribute: String) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { throw AXUIError.attributeFetchFailed }
        return value
    }

    static func getWindowFrame(window: AXUIElement) -> CGRect? {
        guard let posValue = try? getAttribute(element: window, attribute: kAXPositionAttribute),
              let sizeValue = try? getAttribute(element: window, attribute: kAXSizeAttribute) else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard CFGetTypeID(posValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetValue(posValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    static func getWindowTitle(window: AXUIElement) -> String? {
        try? getAttribute(element: window, attribute: kAXTitleAttribute) as? String
    }

    static func setWindowFrame(window: AXUIElement, frame: CGRect) {
        var size = CGSize(width: frame.width, height: frame.height)
        var point = CGPoint(x: frame.origin.x, y: frame.origin.y)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        if let pointValue = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        }
    }

    static func getWindows(for app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let rawList = try? getAttribute(element: appElement, attribute: kAXWindowsAttribute) as? [AXUIElement] else {
            return []
        }
        return rawList
    }

    static func getAppWindowsInfo(_ app: NSRunningApplication) -> [AppWindowInfo] {
        let windows = getWindows(for: app)
        return windows.compactMap { window in
            guard let title = getWindowTitle(window: window),
                  let frame = getWindowFrame(window: window) else { return nil }
            let minimized = (try? getAttribute(element: window, attribute: kAXMinimizedAttribute) as? Bool) ?? false
            return AppWindowInfo(
                bundleID: app.bundleIdentifier ?? "",
                appName: app.localizedName ?? "Unknown",
                windowTitle: title,
                frame: frame,
                isOnTop: app.isActive,
                isMinimized: minimized
            )
        }
    }

    static func snapshotLayouts() -> [AppLayout] {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        return apps.flatMap { app -> [AppLayout] in
            let windows = getWindows(for: app)
            return windows.compactMap { window in
                guard let title = getWindowTitle(window: window),
                      let frame = getWindowFrame(window: window) else { return nil }
                return AppLayout(
                    bundleID: app.bundleIdentifier ?? "",
                    frame: frame,
                    isFrontmost: app.isActive,
                    windowTitle: title
                )
            }
        }
    }

    static func restoreLayouts(_ layouts: [AppLayout]) {
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for layout in layouts {
            guard let app = runningApps.first(where: { $0.bundleIdentifier == layout.bundleID }) else {
                launchApp(bundleID: layout.bundleID)
                continue
            }
            guard let window = getWindows(for: app).first else { continue }
            setWindowFrame(window: window, frame: layout.frame)
            if layout.isFrontmost { app.activate() }
        }
    }

    static func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func extractTabs(from app: NSRunningApplication, window: AXUIElement) -> [String] {
        var urls: [String] = []
        if app.bundleIdentifier == "com.apple.Safari" {
            if let tabs = try? getAttribute(element: window, attribute: "AXTabs") as? [AXUIElement] {
                for tab in tabs {
                    if let url = try? getAttribute(element: tab, attribute: kAXURLAttribute) as? String {
                        urls.append(url)
                    }
                }
            }
        }
        if let bundleID = app.bundleIdentifier, bundleID.contains("chrome") || bundleID.contains("chromium") {
            if let tabs = try? getAttribute(element: window, attribute: "AXTabs") as? [AXUIElement] {
                for tab in tabs {
                    if let title = try? getAttribute(element: tab, attribute: kAXTitleAttribute) as? String {
                        urls.append(title)
                    }
                }
            }
        }
        return urls
    }

    // MARK: - Deep Accessibility Tree

    static func getAccessibilityTree(element: AXUIElement, maxDepth: Int = 8) -> AccessibilityNode? {
        guard maxDepth > 0 else { return nil }
        guard let role = try? getAttribute(element: element, attribute: kAXRoleAttribute) as? String else {
            return nil
        }
        let title = try? getAttribute(element: element, attribute: kAXTitleAttribute) as? String
        let value = try? getAttribute(element: element, attribute: kAXValueAttribute) as? String
        let description = try? getAttribute(element: element, attribute: kAXDescriptionAttribute) as? String
        let isEnabled = (try? getAttribute(element: element, attribute: kAXEnabledAttribute) as? Bool) ?? true
        let isFocused = (try? getAttribute(element: element, attribute: kAXFocusedAttribute) as? Bool) ?? false
        let url = try? getAttribute(element: element, attribute: kAXURLAttribute) as? String

        let position = (try? getAttribute(element: element, attribute: kAXPositionAttribute)).flatMap { value -> CGPoint? in
            var point = CGPoint.zero
            guard CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID(),
                  AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
            return point
        }
        let size = (try? getAttribute(element: element, attribute: kAXSizeAttribute)).flatMap { value -> CGSize? in
            var size = CGSize.zero
            guard CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID(),
                  AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
            return size
        }

        let frame: CGRect
        if let position, let size {
            frame = CGRect(origin: position, size: size)
        } else {
            frame = .zero
        }

        var children: [AccessibilityNode] = []
        if let rawChildren = try? getAttribute(element: element, attribute: kAXChildrenAttribute) as? [AXUIElement] {
            let maxChildren = 30
            for child in rawChildren.prefix(maxChildren) {
                if let childNode = getAccessibilityTree(element: child, maxDepth: maxDepth - 1) {
                    children.append(childNode)
                }
            }
        }

        return AccessibilityNode(
            role: role,
            title: title,
            value: value,
            description: description,
            isEnabled: isEnabled,
            isFocused: isFocused,
            frame: frame,
            children: children,
            url: url
        )
    }

    static func getFocusedElement(in app: NSRunningApplication) -> AccessibilityNode? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let focused = try? getAttribute(element: appElement, attribute: kAXFocusedUIElementAttribute),
              CFGetTypeID(focused as CFTypeRef) == AXUIElementGetTypeID() else {
            return nil
        }
        return getAccessibilityTree(element: focused as! AXUIElement, maxDepth: 2)
    }

    static func getDeepAppContext(for app: NSRunningApplication) -> AppDeepContext? {
        let windows = getWindows(for: app)
        guard let mainWindow = windows.first(where: {
            let minimized = (try? getAttribute(element: $0, attribute: kAXMinimizedAttribute) as? Bool) ?? false
            return !minimized
        }) ?? windows.first else {
            return nil
        }

        let windowTitle = getWindowTitle(window: mainWindow) ?? ""
        let tabs = extractTabs(from: app, window: mainWindow)
        let uiTree = getAccessibilityTree(element: mainWindow, maxDepth: 6)
        let focused = getFocusedElement(in: app)

        var urls: [String] = tabs
        if let tree = uiTree {
            collectURLs(from: tree, into: &urls)
        }

        let activeFile = extractActiveFile(from: uiTree, app: app)
        let uiState = extractUIState(from: uiTree)

        return AppDeepContext(
            bundleID: app.bundleIdentifier ?? "",
            appName: app.localizedName ?? "Unknown",
            windowTitle: windowTitle,
            uiTree: uiTree,
            focusedElement: focused,
            tabs: tabs,
            urls: Array(Set(urls)),
            activeFile: activeFile,
            uiState: uiState
        )
    }

    private static func collectURLs(from node: AccessibilityNode, into urls: inout [String]) {
        if let url = node.url, !url.isEmpty {
            urls.append(url)
        }
        for child in node.children {
            collectURLs(from: child, into: &urls)
        }
    }

    private static func extractActiveFile(from tree: AccessibilityNode?, app: NSRunningApplication) -> String? {
        guard let tree = tree else { return nil }
        if let bundleID = app.bundleIdentifier {
            if bundleID == "com.apple.dt.Xcode" {
                let field = findFirst(role: "AXTextField", in: tree, titleContaining: nil)
                return field?.value ?? field?.title
            }
            if bundleID.contains("vscode") || bundleID.contains("VSCode") {
                let tab = findFirst(role: "AXTab", in: tree, titleContaining: nil)
                return tab?.title
            }
        }
        if let focused = findFirstFocused(in: tree) {
            return focused.title ?? focused.value
        }
        return findDeepestTitle(in: tree)
    }

    private static func extractUIState(from tree: AccessibilityNode?) -> String? {
        guard let tree = tree else { return nil }
        if contains(role: "AXDebugArea", in: tree) { return "debugging" }
        if contains(role: "AXTerminal", in: tree) { return "terminal" }
        if contains(role: "AXFullScreenButton", in: tree) { return "fullscreen" }
        if findFirst(role: "AXSplitGroup", in: tree, titleContaining: nil) != nil {
            return "split_view"
        }
        return nil
    }

    private static func findFirst(role: String, in node: AccessibilityNode, titleContaining substring: String?) -> AccessibilityNode? {
        if node.role == role {
            if let substring = substring {
                if node.title?.localizedCaseInsensitiveContains(substring) == true {
                    return node
                }
            } else {
                return node
            }
        }
        for child in node.children {
            if let found = findFirst(role: role, in: child, titleContaining: substring) {
                return found
            }
        }
        return nil
    }

    private static func findFirstFocused(in node: AccessibilityNode) -> AccessibilityNode? {
        if node.isFocused { return node }
        for child in node.children {
            if let found = findFirstFocused(in: child) {
                return found
            }
        }
        return nil
    }

    private static func findDeepestTitle(in node: AccessibilityNode) -> String? {
        if node.children.isEmpty, let title = node.title, !title.isEmpty {
            return title
        }
        for child in node.children {
            if let found = findDeepestTitle(in: child) {
                return found
            }
        }
        return nil
    }

    private static func contains(role: String, in node: AccessibilityNode) -> Bool {
        if node.role == role { return true }
        for child in node.children {
            if contains(role: role, in: child) { return true }
        }
        return false
    }

    enum AXUIError: Error {
        case attributeFetchFailed
        case accessibilityNotAuthorized
    }
}
