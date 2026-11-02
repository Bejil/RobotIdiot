import Foundation

public struct CarriedItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: String

    public init(id: String, kind: String) {
        self.id = id
        self.kind = kind
    }
}

public struct RobotState: Codable, Hashable, Sendable {
    public var position: GridCoordinate
    public var orientation: Direction
    public var inventory: [CarriedItem]

    public init(position: GridCoordinate, orientation: Direction, inventory: [CarriedItem] = []) {
        self.position = position
        self.orientation = orientation
        self.inventory = inventory
    }
}

public enum ObjectiveKind: String, Codable, Hashable, Sendable {
    case reachFlag
}

public struct Objective: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: ObjectiveKind
    public var position: GridCoordinate
    /// Monde 3 : le drapeau ne compte que si le robot tient encore la clé.
    public var requiresItemHeld: Bool

    public init(id: String, kind: ObjectiveKind, position: GridCoordinate, requiresItemHeld: Bool = false) {
        self.id = id
        self.kind = kind
        self.position = position
        self.requiresItemHeld = requiresItemHeld
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case position
        case requiresItemHeld
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(ObjectiveKind.self, forKey: .kind)
        position = try container.decode(GridCoordinate.self, forKey: .position)
        requiresItemHeld = try container.decodeIfPresent(Bool.self, forKey: .requiresItemHeld) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(position, forKey: .position)
        try container.encode(requiresItemHeld, forKey: .requiresItemHeld)
    }
}

public struct ObjectiveState: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var isCompleted: Bool

    public init(id: String, isCompleted: Bool) {
        self.id = id
        self.isCompleted = isCompleted
    }
}

public struct ExecutionMetrics: Codable, Hashable, Sendable {
    public var executedInstructions: Int
    public var moves: Int
    public var turns: Int
    public var tests: Int
    public var interactions: Int

    public init(
        executedInstructions: Int = 0,
        moves: Int = 0,
        turns: Int = 0,
        tests: Int = 0,
        interactions: Int = 0
    ) {
        self.executedInstructions = executedInstructions
        self.moves = moves
        self.turns = turns
        self.tests = tests
        self.interactions = interactions
    }
}

/// État mutable d'une partie. Il est toujours reconstruit depuis un `Level`,
/// jamais confondu avec la définition du niveau.
public struct GameState: Codable, Hashable, Sendable {
    public var robot: RobotState
    public var grid: Grid
    public var objectives: [ObjectiveState]
    public var metrics: ExecutionMetrics

    public init(robot: RobotState, grid: Grid, objectives: [ObjectiveState], metrics: ExecutionMetrics = ExecutionMetrics()) {
        self.robot = robot
        self.grid = grid
        self.objectives = objectives
        self.metrics = metrics
    }

    public var isVictory: Bool {
        !objectives.isEmpty && objectives.allSatisfy(\.isCompleted)
    }

    public static func initial(from level: Level) -> GameState {
        GameState(
            robot: level.initialRobot,
            grid: level.grid,
            objectives: level.objectives.map { ObjectiveState(id: $0.id, isCompleted: false) }
        )
    }
}
