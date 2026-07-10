import Foundation
import NaturalLanguage

public actor AIService {
    public static let shared = AIService()

    private var isAvailable = false
    private var tagger: NLTagger?

    public func initialize() {
        tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        isAvailable = true
        Log.info("AI Service initialized")
    }

    public var isReady: Bool { isAvailable }

    public func classifyActivity(appIDs: [String], windowTitles: [String], urls: [String]) -> SpaceMode? {
        let combinedText = (appIDs + windowTitles + urls).joined(separator: " ").lowercased()

        if containsCodeKeywords(combinedText) { return .coding }
        if containsCreativeKeywords(combinedText) { return .creative }
        if containsMeetingKeywords(combinedText) { return .meetings }
        if containsDeepWorkKeywords(combinedText) { return .deepWork }
        if containsBrowsingKeywords(combinedText) { return .browsing }

        return nil
    }

    public func suggestSpaceName(from apps: [String], windowTitles: [String]) -> String {
        let classified = classifyActivity(appIDs: apps, windowTitles: windowTitles, urls: [])
        switch classified {
        case .coding: return "Coding Session"
        case .creative: return "Creative Flow"
        case .meetings: return "Meeting"
        case .deepWork: return "Deep Work"
        case .browsing: return "Research"
        case .custom, nil: return "Custom Workspace"
        }
    }

    public func extractEntities(from text: String) -> [String] {
        tagger?.string = text
        var entities: [String] = []
        tagger?.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag, tag == .organizationName || tag == .personalName {
                entities.append(String(text[range]))
            }
            return true
        }
        return entities
    }

    public func analyzeProductivity(
        appUsage: [String: TimeInterval],
        contextSwitches: Int,
        totalTime: TimeInterval
    ) -> ProductivityAnalysis {
        let distractionApps: Set<String> = [
            "com.apple.TV", "com.netflix.Netflix", "com.spotify.client",
            "com.apple.PhotoBooth", "com.apple.gamecenter"
        ]
        let productivityApps: Set<String> = [
            "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.apple.Safari",
            "com.apple.Pages", "com.microsoft.Excel", "com.apple.Terminal"
        ]

        var distractionTime: TimeInterval = 0
        var productiveTime: TimeInterval = 0

        for (appID, time) in appUsage {
            if distractionApps.contains(appID) { distractionTime += time }
            if productivityApps.contains(appID) { productiveTime += time }
        }

        let focusRatio = totalTime > 0 ? (productiveTime - distractionTime) / totalTime : 0
        let productivityScore = clamp((focusRatio + 1) / 2 * 100 - Double(contextSwitches) * 2, min: 0, max: 100)

        return ProductivityAnalysis(
            productiveTime: productiveTime,
            distractionTime: distractionTime,
            contextSwitches: contextSwitches,
            productivityScore: productivityScore,
            suggestion: generateSuggestion(score: productivityScore)
        )
    }

    private func generateSuggestion(score: Double) -> String {
        switch score {
        case 80...100:
            return "Focus score \(Int(score)) — well maintained."
        case 60..<80:
            return "Focus score \(Int(score)) — \(Int(100 - score)) point drop from optimal. Check if background apps are pulling attention."
        case 40..<60:
            return "Focus score \(Int(score)) — moderate fragmentation. Consider enabling Deep Work mode to group similar tasks."
        case 20..<40:
            return "Focus score \(Int(score)) — frequent switching detected. Try blocking known distractors for the next 25 minutes."
        default:
            return "Focus score \(Int(score)) — very high switching rate. A short break may help reset attention."
        }
    }

    private func containsCodeKeywords(_ text: String) -> Bool {
        let keywords = ["xcode", "vscode", "intellij", "terminal", "swift", "python", "javascript",
                        "rust", "go", "compile", "debug", "commit", "pr"]
        return keywords.contains { text.contains($0) }
    }

    private func containsCreativeKeywords(_ text: String) -> Bool {
        let keywords = ["final cut", "affinity", "photoshop", "illustrator", "garageband",
                        "logic pro", "design", "artboard", "canvas", "layer", "blend"]
        return keywords.contains { text.contains($0) }
    }

    private func containsMeetingKeywords(_ text: String) -> Bool {
        let keywords = ["zoom", "teams", "meet", "facetime", "webex", "slack", "call", "meeting",
                        "standup", "sync", "presentation", "screen share"]
        return keywords.contains { text.contains($0) }
    }

    private func containsDeepWorkKeywords(_ text: String) -> Bool {
        let keywords = ["obsidian", "notion", "bear", "drafts", "notes", "writing", "document",
                        "read", "study", "research", "pdf", "book"]
        return keywords.contains { text.contains($0) }
    }

    private func containsBrowsingKeywords(_ text: String) -> Bool {
        let keywords = ["safari", "chrome", "firefox", "arc", "browser", "reddit", "twitter",
                        "youtube", "news", "article", "blog", "github", "gitlab"]
        return keywords.contains { text.contains($0) }
    }

    private func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.min(Swift.max(value, min), max)
    }
}

public struct ProductivityAnalysis: Sendable {
    public var productiveTime: TimeInterval
    public var distractionTime: TimeInterval
    public var contextSwitches: Int
    public var productivityScore: Double
    public var suggestion: String

    public init(productiveTime: TimeInterval, distractionTime: TimeInterval, contextSwitches: Int, productivityScore: Double, suggestion: String) {
        self.productiveTime = productiveTime
        self.distractionTime = distractionTime
        self.contextSwitches = contextSwitches
        self.productivityScore = productivityScore
        self.suggestion = suggestion
    }
}
