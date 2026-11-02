import Foundation

public enum ExecutionStatus: String, Codable, Hashable, Sendable {
    case ready
    case inProgress
    case succeeded
    case failed
    case exhausted
    case safetyStopped

    public var isTerminal: Bool {
        switch self {
        case .ready, .inProgress:
            return false
        case .succeeded, .failed, .exhausted, .safetyStopped:
            return true
        }
    }
}

/// Curseur prêt pour les blocs imbriqués.
/// La phase 1 n'empile qu'une trame de séquence. REPETE ajoutera la politique `forever`
/// sans changer la forme de cet état.
public struct ExecutionCursor: Codable, Hashable, Sendable {
    public struct Frame: Codable, Hashable, Sendable {
        public var containerPath: [Int]
        public var childIndex: Int
        public var policy: Policy

        public init(containerPath: [Int], childIndex: Int, policy: Policy) {
            self.containerPath = containerPath
            self.childIndex = childIndex
            self.policy = policy
        }
    }

    public enum Policy: String, Codable, Hashable, Sendable {
        case sequence
        case forever
    }

    public var frames: [Frame]

    public init(frames: [Frame] = []) {
        self.frames = frames
    }
}

public enum ExecutionFault: Error, Hashable, Sendable, Codable {
    case pathBlocked(command: CommandType, instructionID: UUID, forward: Bool, attempted: GridCoordinate)
    case commandUnavailable(command: CommandType, instructionID: UUID)
    case nothingToPickUp(instructionID: UUID)
    case nothingToUse(instructionID: UUID)
    case incompatibleUse(instructionID: UUID)
    case nothingToPush(instructionID: UUID)
    case pushBlocked(instructionID: UUID, attempted: GridCoordinate)
    case nothingToActivate(instructionID: UUID)
    case missingCondition(instructionID: UUID)
    case cycle(instructionID: UUID)
    case safetyStop
}

public enum SimulationEvent: Hashable, Sendable, Codable {
    case moved(from: GridCoordinate, to: GridCoordinate, forward: Bool, command: CommandType)
    case turned(from: Direction, to: Direction, command: CommandType)
    case pickedUp(CarriedItem, at: GridCoordinate)
    case used(CarriedItem, on: GridCoordinate)
    case pushed(objectID: String, from: GridCoordinate, to: GridCoordinate)
    case activated(mechanismID: String, at: GridCoordinate, isActive: Bool)
    case enteredLoop(UUID)
    case testedCondition(instructionID: UUID, condition: ConditionType, passed: Bool)
    case blocked(ExecutionFault)
    case finishedWithoutGoal
    case succeeded
    case safetyStopped
}

public struct ExecutionRecord: Codable, Hashable, Sendable {
    public var instructionID: UUID
    public var command: CommandType
    public var event: SimulationEvent

    public init(instructionID: UUID, command: CommandType, event: SimulationEvent) {
        self.instructionID = instructionID
        self.command = command
        self.event = event
    }
}

/// Empreinte utilisée plus tard pour reconnaître un cycle.
/// Elle couvre le monde, les objectifs, l'inventaire et la position dans le programme.
/// Les compteurs de métriques en sont exclus : ils changent à chaque pas et masqueraient la boucle.
public struct SimulationFingerprint: Hashable, Sendable {
    public var robot: RobotState
    public var cells: [Cell]
    public var objectives: [ObjectiveState]
    public var cursor: ExecutionCursor

    public init(robot: RobotState, cells: [Cell], objectives: [ObjectiveState], cursor: ExecutionCursor) {
        self.robot = robot
        self.cells = cells
        self.objectives = objectives
        self.cursor = cursor
    }
}

/// Plafond interne du moteur. Ce n'est pas un paramètre de REPETE et il n'est pas exposé au joueur.
public struct SafetyLimits: Equatable, Sendable {
    public var maxInstructionSteps: Int

    public init(maxInstructionSteps: Int) {
        self.maxInstructionSteps = maxInstructionSteps
    }

    public static let standard = SafetyLimits(maxInstructionSteps: 10_000)
}

public struct ExecutionState: Codable, Hashable, Sendable {
    public internal(set) var status: ExecutionStatus
    public internal(set) var game: GameState
    public internal(set) var cursor: ExecutionCursor
    public internal(set) var activeInstructionID: UUID?
    public internal(set) var fault: ExecutionFault?
    public internal(set) var history: [ExecutionRecord]
    public internal(set) var safetyStepCount: Int

    public init(
        status: ExecutionStatus,
        game: GameState,
        cursor: ExecutionCursor = ExecutionCursor(),
        activeInstructionID: UUID? = nil,
        fault: ExecutionFault? = nil,
        history: [ExecutionRecord] = [],
        safetyStepCount: Int = 0
    ) {
        self.status = status
        self.game = game
        self.cursor = cursor
        self.activeInstructionID = activeInstructionID
        self.fault = fault
        self.history = history
        self.safetyStepCount = safetyStepCount
    }

    public var fingerprint: SimulationFingerprint {
        SimulationFingerprint(
            robot: game.robot,
            cells: game.grid.cells,
            objectives: game.objectives,
            cursor: cursor
        )
    }

    public static func ready(level: Level) -> ExecutionState {
        ExecutionState(status: .ready, game: .initial(from: level))
    }
}
