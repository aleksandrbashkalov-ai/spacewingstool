import Foundation

public actor SignalPrioritizationService {
    public static let shared = SignalPrioritizationService()

    private let productivePeakStart = 8
    private let productivePeakEnd = 12
    private let afternoonPeakStart = 14
    private let afternoonPeakEnd = 17

    private init() {}

    public func weightEvent(_ record: ActivityRecord) -> WeightedEvent {
        var score = 0
        var reasons: [String] = []

        let typeBonus: Int
        switch record.activityType {
        case .meeting:
            typeBonus = 20
            reasons.append("meeting (+20)")
        case .writing, .coding:
            typeBonus = 15
            reasons.append("\(record.activityType.rawValue) (+15)")
        case .reading:
            typeBonus = 10
            reasons.append("reading (+10)")
        case .email:
            typeBonus = 5
            reasons.append("email (+5)")
        case .browsing:
            typeBonus = 0
        default:
            typeBonus = 0
        }
        score += typeBonus

        let dur = record.duration
        if dur > 3600 {
            score += 15
            reasons.append(">1h (+15)")
        } else if dur > 1800 {
            score += 10
            reasons.append(">30m (+10)")
        } else if dur > 300 {
            score += 5
            reasons.append(">5m (+5)")
        } else if dur < 120 && dur > 0 {
            score -= 5
            reasons.append("<2m (-5)")
        }

        if record.confidence > 0.8 {
            score += 10
            reasons.append("high confidence (+10)")
        }

        if record.activityType == .meeting,
           let metaJSON = record.metadataJSON,
           let data = metaJSON.data(using: .utf8),
           let meta = try? JSONDecoder().decode(MeetingMetadata.self, from: data) {
            if meta.isPresenting == true {
                score += 15
                reasons.append("presenting (+15)")
            }
            if meta.isScreenSharing == true {
                score += 10
                reasons.append("screen sharing (+10)")
            }
            if meta.transcriptionAvailable == true {
                score += 10
                reasons.append("transcription (+10)")
            }
        }

        let hoursSince = abs(record.timestamp.timeIntervalSinceNow) / 3600
        let recencyPenalty = Int(hoursSince * 0.5)
        if recencyPenalty > 0 {
            score -= recencyPenalty
            reasons.append("recency (-\(recencyPenalty))")
        }

        let hour = Calendar.current.component(.hour, from: record.timestamp)
        if (productivePeakStart...productivePeakEnd).contains(hour) || (afternoonPeakStart...afternoonPeakEnd).contains(hour) {
            score += 5
            reasons.append("peak hours (+5)")
        }

        let weight: SignalWeight
        if score >= 40 {
            weight = .critical
        } else if score >= 25 {
            weight = .high
        } else if score >= 15 {
            weight = .moderate
        } else {
            weight = .routine
        }

        return WeightedEvent(
            record: record,
            weight: weight,
            score: score,
            explanation: reasons.joined(separator: ", ")
        )
    }

    public func weightEvents(_ records: [ActivityRecord]) -> [WeightedEvent] {
        records.map { weightEvent($0) }
            .sorted { $0.score > $1.score }
    }

    public func eventsByWeight(_ records: [ActivityRecord]) -> [SignalWeight: [WeightedEvent]] {
        Dictionary(grouping: weightEvents(records)) { $0.weight }
    }
}
