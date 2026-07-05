import AppKit
import Foundation

public actor MemoryService {
    public static let shared = MemoryService()

    private let persistence = PersistenceService.shared

    public func saveSnapshot(name: String, space: Space?) async -> SessionSnapshot {
        let snapshot = SessionSnapshot(
            name: name,
            spaceID: space?.id,
            spaceName: space?.name ?? "Unknown",
            appLayouts: space?.appLayouts ?? []
        )
        var snapshots = await loadAllSnapshots()
        snapshots.insert(snapshot, at: 0)
        if snapshots.count > Constants.maxSnapshotCount {
            snapshots = Array(snapshots.prefix(Constants.maxSnapshotCount))
        }
        await persistence.save(snapshots, key: "snapshots")
        return snapshot
    }

    public func loadAllSnapshots() async -> [SessionSnapshot] {
        await persistence.load([SessionSnapshot].self, key: "snapshots") ?? []
    }

    public func loadSnapshots(limit: Int = 20) async -> [SessionSnapshot] {
        Array((await loadAllSnapshots()).prefix(limit))
    }

    public func deleteSnapshot(_ snapshot: SessionSnapshot) async {
        var snapshots = await loadAllSnapshots()
        snapshots.removeAll { $0.id == snapshot.id }
        await persistence.save(snapshots, key: "snapshots")
    }

    public func restoreSnapshot(_ snapshot: SessionSnapshot) {
        for layout in snapshot.appLayouts {
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == layout.bundleID
            }) else {
                launchApp(bundleID: layout.bundleID)
                continue
            }
            restoreWindow(for: app, layout: layout)
        }
    }

    private func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func restoreWindow(for app: NSRunningApplication, layout: AppLayout) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowList: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
              let windows = windowList as? [AXUIElement] else { return }

        if let window = windows.first {
            var size = CGSize(width: layout.frame.width, height: layout.frame.height)
            var point = CGPoint(x: layout.frame.origin.x, y: layout.frame.origin.y)
            guard let sizeValue = AXValueCreate(.cgSize, &size),
                  let pointValue = AXValueCreate(.cgPoint, &point) else { return }
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)

            if layout.isFrontmost {
                app.activate()
            }
        }
    }

    public func logProductivity(
        date: Date,
        spaceName: String,
        timeSpent: TimeInterval,
        appUsage: [String: TimeInterval],
        contextSwitches: Int,
        productivityScore: Double
    ) async {
        let stats = ProductivityStats(
            date: date,
            spaceName: spaceName,
            timeSpent: timeSpent,
            appUsage: appUsage,
            contextSwitches: contextSwitches,
            productivityScore: productivityScore
        )
        var history = await loadAllProductivity()
        history.append(stats)
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        history = history.filter { $0.date >= cutoff }
        await persistence.save(history, key: "productivity")
    }

    public func loadAllProductivity() async -> [ProductivityStats] {
        await persistence.load([ProductivityStats].self, key: "productivity") ?? []
    }

    public func getProductivityHistory(days: Int = 7) async -> [ProductivityStats] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return (await loadAllProductivity()).filter { $0.date >= startDate }
    }
}
