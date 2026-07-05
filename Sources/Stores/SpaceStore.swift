import Foundation
import Observation

@MainActor
@Observable
public final class SpaceStore {
    public static let shared = SpaceStore()

    public var spaces: [Space] = []
    public var activeSpace: Space?
    public var isAutoSwitchEnabled = true
    public var suggestedSpace: Space?
    public var currentContext: DetectedContext?

    private let persistence = PersistenceService.shared
    private var contextTask: Task<Void, Never>?

    private init() {
        Task { await loadSpaces() }
        observeContext()
    }

    private func observeContext() {
        contextTask = Task { [weak self] in
            guard let self = self else { return }
            for await context in ContextAnalyzer.shared.contextUpdates {
                self.currentContext = context
                self.evaluateContext(context)
            }
        }
    }

    public func loadSpaces() async {
        if let saved: [Space] = await persistence.load([Space].self, key: "spaces"), !saved.isEmpty {
            spaces = saved
        } else {
            spaces = Space.defaultSpaces
            await persistSpaces()
        }
        activeSpace = spaces.first(where: { $0.isActive })
    }

    public func activateSpace(_ space: Space) {
        var updated = space
        if let current = activeSpace {
            if let idx = spaces.firstIndex(where: { $0.id == current.id }) {
                spaces[idx].isActive = false
            }
        }
        updated.isActive = true
        updated.lastUsedAt = Date()
        updated.useCount += 1
        if let idx = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[idx] = updated
        }
        activeSpace = updated
        suggestedSpace = nil
        Task { await persistSpaces() }
        AXUIHelper.restoreLayouts(updated.appLayouts)
    }

    public func deactivateCurrentSpace() {
        guard let current = activeSpace else { return }
        if let idx = spaces.firstIndex(where: { $0.id == current.id }) {
            spaces[idx].isActive = false
        }
        activeSpace = nil
        Task { await persistSpaces() }
    }

    public func addSpace(name: String, mode: SpaceMode = .custom) {
        let space = Space(name: name, mode: mode)
        spaces.append(space)
        Task { await persistSpaces() }
    }

    public func removeSpace(_ space: Space) {
        spaces.removeAll { $0.id == space.id }
        if activeSpace?.id == space.id { activeSpace = nil }
        Task { await persistSpaces() }
    }

    public func toggleFavorite(_ space: Space) {
        guard let idx = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces[idx].isFavorite.toggle()
        Task { await persistSpaces() }
    }

    public func updateSpace(_ space: Space) {
        guard let idx = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces[idx] = space
        if activeSpace?.id == space.id { activeSpace = space }
        Task { await persistSpaces() }
    }

    public func evaluateContext(_ context: DetectedContext) {
        guard isAutoSwitchEnabled else {
            suggestedSpace = nil
            return
        }
        guard let matched = findBestMatch(for: context) else {
            suggestedSpace = nil
            return
        }
        if matched.id != activeSpace?.id {
            suggestedSpace = matched
        }
    }

    private func findBestMatch(for context: DetectedContext) -> Space? {
        var bestMatch: Space?
        var bestScore = 0.0

        for space in spaces {
            var score = 0.0
            for trigger in space.triggers {
                switch trigger {
                case .appRunning(let bundleIDs):
                    let matchCount = context.activeApps.filter { bundleIDs.contains($0) }.count
                    if matchCount > 0 { score += Double(matchCount) * 2.0 }
                case .calendarEvent(let keywords):
                    let matchCount = context.calendarEvents.filter { event in
                        keywords.contains { event.title.localizedCaseInsensitiveContains($0) }
                    }.count
                    score += Double(matchCount) * 3.0
                case .timeRange(let start, let end):
                    let now = Date()
                    if now >= start && now <= end { score += 1.5 }
                case .focusMode(let name):
                    if context.focusMode == name { score += 2.5 }
                case .urlPattern(let pattern):
                    if context.activeURLs.contains(where: { $0.localizedCaseInsensitiveContains(pattern) }) { score += 1.0 }
                case .manual: break
                }
            }
            if score > bestScore {
                bestScore = score
                bestMatch = space
            }
        }
        return bestScore >= 2.0 ? bestMatch : nil
    }

    public func snapshotCurrentLayout(for space: inout Space) {
        space.appLayouts = AXUIHelper.snapshotLayouts()
    }

    private func persistSpaces() async {
        await persistence.save(spaces, key: "spaces")
    }
}
