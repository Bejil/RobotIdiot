import Foundation

/// Familles d'énigmes que cette version du générateur sait construire.
public enum PuzzleFamily: String, Codable, Hashable, Sendable, CaseIterable {
    case openWalk
    case obstacleWalk
    case infiniteCorridor
    case wallFollow
    case keyDoor
    case switchDoor
    case cratePush

    public var requiresLoop: Bool {
        switch self {
        case .infiniteCorridor, .wallFollow:
            return true
        case .openWalk, .obstacleWalk, .keyDoor, .switchDoor, .cratePush:
            return false
        }
    }

    public var requiresCondition: Bool {
        self == .wallFollow
    }

    public var requiresInteraction: Bool {
        switch self {
        case .keyDoor, .switchDoor, .cratePush:
            return true
        case .openWalk, .obstacleWalk, .infiniteCorridor, .wallFollow:
            return false
        }
    }
}

public struct GenerationRequest: Codable, Hashable, Sendable {
    public var seed: UInt64
    public var generatorVersion: Int
    public var worldNumber: Int
    public var levelNumber: Int
    public var targetDifficulty: Double
    public var family: PuzzleFamily?
    public var allowedMechanisms: [String]
    public var theme: ThemeIdentifier

    public init(
        seed: UInt64,
        generatorVersion: Int,
        worldNumber: Int,
        levelNumber: Int,
        targetDifficulty: Double,
        family: PuzzleFamily? = nil,
        allowedMechanisms: [String] = [],
        theme: ThemeIdentifier = .laboratory
    ) {
        self.seed = seed
        self.generatorVersion = generatorVersion
        self.worldNumber = worldNumber
        self.levelNumber = levelNumber
        self.targetDifficulty = min(1, max(0, targetDifficulty))
        self.family = family
        self.allowedMechanisms = allowedMechanisms
        self.theme = theme
    }
}

public struct DifficultyProfile: Equatable, Sendable {
    public var target: Double
    public var maximumSpan: Int
    public var family: PuzzleFamily

    public init(target: Double, maximumSpan: Int, family: PuzzleFamily) {
        self.target = target
        self.maximumSpan = maximumSpan
        self.family = family
    }
}

public enum DifficultyModel {
    /// La taille reste bornée. La difficulté monte surtout par la famille d'énigme.
    public static func profile(target: Double, rng: inout SeededGenerator) -> DifficultyProfile {
        let clamped = min(1, max(0, target))
        let span: Int
        if clamped < 0.35 {
            span = 6
        } else if clamped < 0.7 {
            span = 7
        } else {
            span = 8
        }
        return DifficultyProfile(target: clamped, maximumSpan: span, family: family(for: clamped, rng: &rng))
    }

    private static func family(for difficulty: Double, rng: inout SeededGenerator) -> PuzzleFamily {
        let roll = rng.int(0..<100)
        if difficulty < 0.35 {
            return roll < 65 ? .openWalk : .obstacleWalk
        }
        if difficulty < 0.62 {
            return roll < 45 ? .obstacleWalk : .infiniteCorridor
        }
        return roll < 30 ? .infiniteCorridor : .wallFollow
    }
}

public struct GenerationBudget: Equatable, Sendable {
    public var maxAttempts: Int
    public var solver: SolverBudget

    public init(maxAttempts: Int, solver: SolverBudget) {
        self.maxAttempts = maxAttempts
        self.solver = solver
    }

    public static let interactive = GenerationBudget(
        maxAttempts: 8,
        solver: SolverBudget(maxPrograms: 800, maxSteps: 12_000)
    )
}

/// Annulation coopérative entre deux tentatives. Le générateur reste synchrone.
public final class GenerationCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

public struct SolverBudget: Equatable, Sendable {
    public var maxPrograms: Int
    public var maxSteps: Int

    public init(maxPrograms: Int, maxSteps: Int) {
        self.maxPrograms = maxPrograms
        self.maxSteps = maxSteps
    }
}

public enum SolverConclusion: String, Codable, Hashable, Sendable {
    /// Une solution existe dans l'espace exploré.
    case found
    /// L'espace annoncé a été parcouru entièrement, sans solution.
    case absent
    /// Le budget a coupé la recherche avant une conclusion.
    case interrupted
}

public struct SolverResult: Sendable {
    public var conclusion: SolverConclusion
    public var program: Program?
    public var metrics: ExecutionMetrics?
    public var exploredPrograms: Int
    public var exploredSteps: Int

    public init(
        conclusion: SolverConclusion,
        program: Program? = nil,
        metrics: ExecutionMetrics? = nil,
        exploredPrograms: Int,
        exploredSteps: Int
    ) {
        self.conclusion = conclusion
        self.program = program
        self.metrics = metrics
        self.exploredPrograms = exploredPrograms
        self.exploredSteps = exploredSteps
    }
}

public struct ValidationResult: Equatable, Sendable {
    public var status: ValidationStatus
    public var estimatedDifficulty: Double
    public var qualityScore: Double
    public var solverConclusion: SolverConclusion
    public var exploredPrograms: Int
    public var rejectionReasons: [String]

    public init(
        status: ValidationStatus,
        estimatedDifficulty: Double,
        qualityScore: Double,
        solverConclusion: SolverConclusion,
        exploredPrograms: Int,
        rejectionReasons: [String]
    ) {
        self.status = status
        self.estimatedDifficulty = estimatedDifficulty
        self.qualityScore = qualityScore
        self.solverConclusion = solverConclusion
        self.exploredPrograms = exploredPrograms
        self.rejectionReasons = rejectionReasons
    }
}

public struct GeneratedLevel: Sendable {
    public var level: Level
    public var referenceProgram: Program
    public var validation: ValidationResult
    public var usedFallback: Bool

    public init(level: Level, referenceProgram: Program, validation: ValidationResult, usedFallback: Bool) {
        self.level = level
        self.referenceProgram = referenceProgram
        self.validation = validation
        self.usedFallback = usedFallback
    }
}
