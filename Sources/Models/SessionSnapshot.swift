import Foundation

public struct SessionSnapshot: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var spaceID: UUID?
    public var spaceName: String
    public var createdAt: Date
    public var appLayouts: [AppLayout]
    public var notes: String
    public var tags: [String]
    public var duration: TimeInterval

    public init(
        id: UUID = UUID(),
        name: String,
        spaceID: UUID? = nil,
        spaceName: String = "",
        createdAt: Date = Date(),
        appLayouts: [AppLayout] = [],
        notes: String = "",
        tags: [String] = [],
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.name = name
        self.spaceID = spaceID
        self.spaceName = spaceName
        self.createdAt = createdAt
        self.appLayouts = appLayouts
        self.notes = notes
        self.tags = tags
        self.duration = duration
    }
}
