import Foundation

public enum SignalWeight: String, Codable, Sendable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case moderate = "Moderate"
    case routine = "Routine"
}

public struct WeightedEvent: Codable, Sendable, Identifiable, Equatable {
    public var id: String { record.id }
    public var record: ActivityRecord
    public var weight: SignalWeight
    public var score: Int
    public var explanation: String

    public init(record: ActivityRecord, weight: SignalWeight, score: Int, explanation: String) {
        self.record = record
        self.weight = weight
        self.score = score
        self.explanation = explanation
    }
}
