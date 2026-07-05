import Foundation
import NaturalLanguage

public actor LocalAIProvider: AIProvider {
    public static let shared = LocalAIProvider()

    private let tagger: NLTagger
    private init() {
        tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .sentimentScore, .language])
    }

    public func generateSummary(systemPrompt: String, userMessage: String) async throws -> String {
        let combined = "\(systemPrompt)\n\(userMessage)"

        let entities = extractEntities(from: combined)
        let classification = classify(combined)
        let sentiment = analyzeSentiment(combined)
        let keywords = extractKeywords(from: combined, max: 5)
        let language = tagger.dominantLanguage

        var parts: [String] = [
            "📊 Activity: \(classification)",
        ]

        if !entities.isEmpty {
            parts.append("👤 Key people/organizations: \(entities.joined(separator: ", "))")
        }

        if !keywords.isEmpty {
            parts.append("🏷 Keywords: \(keywords.joined(separator: ", "))")
        }

        parts.append("📈 Sentiment: \(sentiment)")

        if let lang = language {
            parts.append("🌐 Language: \(lang.rawValue)")
        }

        return parts.joined(separator: "\n")
    }

    private func extractEntities(from text: String) -> [String] {
        tagger.string = text
        var entities: Set<String> = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag, tag == .organizationName || tag == .personalName || tag == .placeName {
                let word = String(text[range])
                if word.count > 1 { entities.insert(word) }
            }
            return true
        }
        return Array(entities).sorted()
    }

    private func extractKeywords(from text: String, max: Int) -> [String] {
        tagger.string = text
        var wordFreq: [String: Int] = [:]
        let stopWords: Set<String> = ["the", "a", "an", "is", "are", "was", "were", "be", "been",
                                       "being", "have", "has", "had", "do", "does", "did", "will",
                                       "would", "could", "should", "may", "might", "shall", "can",
                                       "to", "of", "in", "for", "on", "with", "at", "by", "from",
                                       "as", "into", "through", "during", "before", "after", "and",
                                       "but", "or", "nor", "not", "so", "yet", "if", "this", "that",
                                       "it", "its", "these", "those", "i", "me", "my", "we", "our",
                                       "you", "your", "he", "him", "his", "she", "her", "they", "them",
                                       "their", "what", "which", "who", "whom", "when", "where", "why",
                                       "how", "all", "each", "every", "both", "few", "more", "most",
                                       "some", "any", "no", "only", "own", "same", "very", "just"]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            let word = String(text[range]).lowercased().trimmingCharacters(in: .punctuationCharacters)
            if word.count >= 3, !stopWords.contains(word) {
                wordFreq[word, default: 0] += 1
            }
            return true
        }

        return wordFreq.sorted { $0.value > $1.value }.prefix(max).map(\.key)
    }

    private func classify(_ text: String) -> String {
        let lower = text.lowercased()

        var scores: [(String, Int)] = []

        let patterns: [(String, [String])] = [
            ("Meeting", ["meeting", "call", "sync", "standup", "agenda", "zoom", "teams", "discuss",
                         "presentation", "review", "workshop", "catch-up", "catch up"]),
            ("Coding", ["coding", "code", "implement", "debug", "compile", "refactor", "pull request",
                        "pr", "commit", "deploy", "test", "function", "class", "api", "endpoint"]),
            ("Writing", ["writing", "document", "email", "draft", "compose", "edit", "note", "report",
                         "proposal", "article", "blog", "write", "type"]),
            ("Research", ["research", "reading", "study", "learn", "tutorial", "documentation",
                          "wiki", "article", "paper", "analyze", "analysis"]),
            ("Deep Work", ["deep work", "focus", "concentrate", "flow", "pomodoro", "session",
                           "block", "uninterrupted"]),
            ("Planning", ["plan", "sprint", "roadmap", "strategy", "goal", "milestone", "timeline",
                          "schedule", "organize", "prioritize"]),
        ]

        for (category, keywords) in patterns {
            let score = keywords.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
            if score > 0 { scores.append((category, score)) }
        }

        guard let best = scores.max(by: { $0.1 < $1.1 }) else { return "General" }
        return best.0
    }

    private func analyzeSentiment(_ text: String) -> String {
        tagger.string = text
        var totalScore: Double = 0
        var count = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }

        let avg = count > 0 ? totalScore / Double(count) : 0
        switch avg {
        case ..<(-0.5): return "negative"
        case -0.5...0.5: return "neutral"
        default: return "positive"
        }
    }
}
