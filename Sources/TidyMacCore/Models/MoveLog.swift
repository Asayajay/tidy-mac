import Foundation

public struct MoveLogEntry: Codable, Equatable, Identifiable {
    public var id: UUID
    public var sourcePath: String
    public var destinationPath: String
    public var ruleName: String
    public var timestamp: Date

    public init(id: UUID = UUID(), sourcePath: String, destinationPath: String, ruleName: String, timestamp: Date) {
        self.id = id
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.ruleName = ruleName
        self.timestamp = timestamp
    }
}

/// One run's worth of moves, logged as a unit so it can be undone as a unit.
public struct MoveBatch: Codable, Equatable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var entries: [MoveLogEntry]
    public var undone: Bool
    /// Directories this batch created that didn't exist before. Undo removes these if
    /// (and only if) they're empty afterward, so undoing doesn't leave stray empty
    /// "Screenshots" / "Documents/PDFs" folders behind -- but it never removes a
    /// directory the user already had, since that never goes in this list.
    public var createdDirectories: [String]

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        entries: [MoveLogEntry],
        undone: Bool = false,
        createdDirectories: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.entries = entries
        self.undone = undone
        self.createdDirectories = createdDirectories
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, entries, undone, createdDirectories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        entries = try container.decode([MoveLogEntry].self, forKey: .entries)
        undone = try container.decode(Bool.self, forKey: .undone)
        createdDirectories = try container.decodeIfPresent([String].self, forKey: .createdDirectories) ?? []
    }
}
