import Foundation

public struct ProductivityStats: Codable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var spaceID: UUID?
    public var spaceName: String
    public var timeSpent: TimeInterval
    public var appUsage: [String: TimeInterval]
    public var contextSwitches: Int
    public var productivityScore: Double

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        spaceID: UUID? = nil,
        spaceName: String = "",
        timeSpent: TimeInterval = 0,
        appUsage: [String: TimeInterval] = [:],
        contextSwitches: Int = 0,
        productivityScore: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.spaceID = spaceID
        self.spaceName = spaceName
        self.timeSpent = timeSpent
        self.appUsage = appUsage
        self.contextSwitches = contextSwitches
        self.productivityScore = productivityScore
    }
}
