import AppKit
import ApplicationServices
import Foundation

public actor WindowMonitor {
    public static let shared = WindowMonitor()

    private var isMonitoring = false
    private var lastKnownWindows: [AppWindowInfo] = []
    private var cachedElements: [pid_t: AXUIElement] = [:]
    private var activeAppID: String = ""
    private var activeAppName: String = ""
    private var pollingInterval: TimeInterval = 2.0
    private var monitoringTask: Task<Void, Never>?

    private let (windowStream, windowContinuation) = AsyncStream<[AppWindowInfo]>.makeStream()
    private let (focusStream, focusContinuation) = AsyncStream<(id: String, name: String)>.makeStream()

    public nonisolated var windows: AsyncStream<[AppWindowInfo]> { windowStream }
    public nonisolated var focusChanges: AsyncStream<(id: String, name: String)> { focusStream }

    public nonisolated var isAccessibilityAuthorized: Bool {
        AXIsProcessTrusted()
    }

    public nonisolated func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public func startMonitoring(interval: TimeInterval = 2.0) {
        guard !isMonitoring else { return }
        guard isAccessibilityAuthorized else {
            Log.error("Accessibility permission not granted. Window monitoring cannot start.")
            requestAccessibilityPermission()
            return
        }
        isMonitoring = true
        pollingInterval = max(interval, 0.5)
        setupFocusObserver()
        Task { await scanWindows() }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled, let self = self {
                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
                await self.scanWindows()
            }
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    public func setPollingInterval(_ interval: TimeInterval) {
        pollingInterval = max(interval, 0.5)
    }

    public func scanWindows() async {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }

        let newWindows = await MainActor.run {
            var result: [AppWindowInfo] = []
            for app in runningApps {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                guard let windowList = try? AXUIHelper.getAttribute(element: appElement, attribute: kAXWindowsAttribute) as? [AXUIElement] else {
                    continue
                }
                for window in windowList {
                    guard let title = AXUIHelper.getWindowTitle(window: window),
                          let frame = AXUIHelper.getWindowFrame(window: window) else { continue }
                    let minimized = (try? AXUIHelper.getAttribute(element: window, attribute: kAXMinimizedAttribute) as? Bool) ?? false
                    let tabs = AXUIHelper.extractTabs(from: app, window: window)
                    let info = AppWindowInfo(
                        bundleID: app.bundleIdentifier ?? "",
                        appName: app.localizedName ?? "Unknown",
                        windowTitle: title,
                        frame: frame,
                        isOnTop: app.isActive,
                        isMinimized: minimized,
                        tabs: tabs
                    )
                    result.append(info)
                }
            }
            return result
        }

        let hasChanges = newWindows != lastKnownWindows
        cachedElements.removeAll()
        lastKnownWindows = newWindows
        if hasChanges {
            windowContinuation.yield(newWindows)
        }
    }

    private func setupFocusObserver() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let id = app.bundleIdentifier ?? ""
            let name = app.localizedName ?? ""
            Task {
                await self.handleFocusChange(id: id, name: name)
            }
        }
    }

    private func handleFocusChange(id: String, name: String) async {
        activeAppID = id
        activeAppName = name
        await scanWindows()
        focusContinuation.yield((id, name))
    }

    public func getActiveAppID() -> String { activeAppID }
    public func getActiveAppName() -> String { activeAppName }

    public nonisolated func getRunningAppIDs() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleIdentifier }
    }

    public nonisolated func getFrontmostApp() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    public nonisolated func getFrontmostWindowTitle() async -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "" }
        return await MainActor.run {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let rawWindow = try? AXUIHelper.getAttribute(element: appElement, attribute: kAXFocusedWindowAttribute),
                  CFGetTypeID(rawWindow as CFTypeRef) == AXUIElementGetTypeID(),
                  let title = AXUIHelper.getWindowTitle(window: rawWindow as! AXUIElement) else {
                return ""
            }
            return title
        }
    }

    public func clearCache() {
        cachedElements.removeAll()
    }
}
